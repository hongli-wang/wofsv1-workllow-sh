#!/bin/csh
# task_02_prior_inflation.csh
#
# Usage:
#   source task_02_prior_inflation.csh YYYYMMDDHHMM
#
# Run with source so the original csh variables and environment remain
# available to the calling driver.
#
# Slurm settings preserved from RUN_WOFS_RLT.csh.

if ( $#argv < 1 ) then
    echo "Usage: source task_02_prior_inflation.csh YYYYMMDDHHMM"
    exit 1
endif

set thisstart = "$argv[1]"
set datea = "$argv[1]"

# ----------------------------------------------------------------------
# Environment
# ----------------------------------------------------------------------
source /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/module_list_intel_15_wps.csh

set GSIRLT = /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/WOFenv_rlt_2026
source ${GSIRLT}

set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
source ${ENVFILE}

set DOMAIN = 01

if ( ! -d "${ENKFDIR}" ) then
    echo "ERROR: ENKFDIR does not exist: ${ENKFDIR}"
    exit 1
endif

if ( ! -d "${RUNDIR}/${thisstart}" ) then
    mkdir -p "${RUNDIR}/${thisstart}"
    if ( $status != 0 ) then
        echo "ERROR: Cannot create ${RUNDIR}/${thisstart}"
        exit 1
    endif
endif

mkdir -p "${RUNDIR}/${thisstart}/diag_${DOMAIN}"

cd "${ENKFDIR}"
if ( $status != 0 ) then
    echo "ERROR: Cannot enter ${ENKFDIR}"
    exit 1
endif

# ----------------------------------------------------------------------
# Write EnKF namelist
# ----------------------------------------------------------------------
if ( -e "${ENKFDIR}/enkf.sed" ) /bin/rm -f "${ENKFDIR}/enkf.sed"
if ( -e "${ENKFDIR}/enkf.nml" ) /bin/rm -f "${ENKFDIR}/enkf.nml"

cat >! "${ENKFDIR}/enkf.sed" << EOF
/datestring=/c\\
datestring="${datea}",
/datapath=/c\\
datapath="${ENKFDIR}/",
/analpertwtnh=/c\\
analpertwtnh=${ANALPERTWTNH3KM},
/analpertwtsh=/c\\
analpertwtsh=${ANALPERTWTSH},
/analpertwttr=/c\\
analpertwttr=${ANALPERTWTTR},
/corrlengthnh=/c\\
corrlengthnh=${CORRLENGTHNH},
/corrlengthsh=/c\\
corrlengthsh=${CORRLENGTHSH},
/corrlengthtr=/c\\
corrlengthtr=${CORRLENGTHTR},
/lnsigcutoffnh=/c\\
lnsigcutoffnh=${LNSIGCUTOFFNH},
/lnsigcutoffsh=/c\\
lnsigcutoffsh=${LNSIGCUTOFFSH},
/lnsigcutofftr=/c\\
lnsigcutofftr=${LNSIGCUTOFFTR},
/lnsigcutoffpsnh=/c\\
lnsigcutoffpsnh=${LNSIGCUTOFFPSNH},
/lnsigcutoffpssh=/c\\
lnsigcutoffpssh=${LNSIGCUTOFFPSSH},
/lnsigcutoffpstr=/c\\
lnsigcutoffpstr=${LNSIGCUTOFFPSTR},
/nlons=/c\\
nlons=${NLONS},
/nlats=/c\\
nlats=${NLATS},
/nlevs=/c\\
nlevs=${NLEVS},
/nanals=/c\\
nanals=${NANALS},
/nvars=/c\\
nvars=${NVARS},
/prior_inf=/c\\
prior_inf=${PRIOR_INF},
/fgfileprefixes =/c\\
fgfileprefixes = 'wrfinput_d${DOMAIN}.','','','','','','',
/anlfileprefixes =/c\\
anlfileprefixes = 'wrfinput_d${DOMAIN}.','','','','','','',
/prior_inf_file =/c\\
prior_inf_file = 'prior_inf_d${DOMAIN}',
/prior_inf_sd_file =/c\\
prior_inf_sd_file = 'prior_inf_sd_d${DOMAIN}',
EOF

/bin/cp -p "${TEMPLATE_DIR}/enkf.nml.template" "${ENKFDIR}/enkf.nml.temp"
if ( $status != 0 ) then
    echo "ERROR: Cannot copy enkf.nml.template"
    exit 1
endif

sed -f "${ENKFDIR}/enkf.sed" "${ENKFDIR}/enkf.nml.temp" >! "${ENKFDIR}/enkf.nml"
if ( $status != 0 ) then
    echo "ERROR: Failed to generate enkf.nml"
    exit 1
endif

# ----------------------------------------------------------------------
# Prior inflation disabled: finish after namelist generation
# ----------------------------------------------------------------------
if ( ${PRIOR_INF} != 1 ) then
    echo "Prior inflation disabled for ${datea}"
    exit 0
endif

# ----------------------------------------------------------------------
# Initialize inflation files if either is missing
# ----------------------------------------------------------------------
if ( ! -e "${ENKFDIR}/prior_inf_d${DOMAIN}.1" || ! -e "${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1" ) then

    echo "Initializing prior inflation files for ${datea}"

    # Remove stale completion flag before submitting the job.
    if ( -e "${ENKFDIR}/init_inf_done" ) then
        /bin/rm -f "${ENKFDIR}/init_inf_done"
    endif

    set initjob = "${ENKFDIR}/runinitinf.job"

    echo "#\!/bin/csh" >! "${initjob}"
    echo "#SBATCH -J runinitinf" >> "${initjob}"
    echo "#SBATCH -o ${ENKFDIR}/runinitinf.log.${thisstart}" >> "${initjob}"
    echo "#SBATCH -e ${ENKFDIR}/runinitinf.err.${thisstart}" >> "${initjob}"
    echo "#SBATCH -p u1-compute" >> "${initjob}"
    echo "#SBATCH -q debug" >> "${initjob}"
    echo "#SBATCH --mem-per-cpu=6G" >> "${initjob}"
    echo "#SBATCH -n ${INF_CORES}" >> "${initjob}"
    echo "#SBATCH -t 00:10:00" >> "${initjob}"

    cat >> "${initjob}" << EOF
module purge
module load intel-oneapi-compilers/2023.2.0
module load intel-oneapi-mpi/2021.13.1
module load intel-oneapi-mkl/2024.2.1
module load hdf5/1.14.3
module load netcdf-c/4.9.2
module load netcdf-fortran/4.6.1

source ${ENVFILE}
set echo

cd ${ENKFDIR}
if ( \$?SLURM_NTASKS ) then
    set ncores = \$SLURM_NTASKS
else
    set ncores = ${INF_CORES}
endif

srun -n \$ncores ${RUNDIR}/GSI_RUN/init_inf
if ( \$status == 0 && -e "${ENKFDIR}/prior_inf_d${DOMAIN}.1" && -e "${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1" ) then
    touch "${ENKFDIR}/init_inf_done"
else
    echo "ERROR: init_inf failed or did not create both inflation files"
    exit 1
endif
exit 0
EOF

    cd "${ENKFDIR}"
    sbatch "${initjob}"
    if ( $status != 0 ) then
        echo "ERROR: Could not submit initialization job"
        exit 1
    endif

    while ( ! -e "${ENKFDIR}/init_inf_done" )
        echo "WAITING FOR INITIALIZING INFLATION TO FINISH"
        sleep 3
    end
endif

# Verify both files before copying or running prior inflation.
if ( ! -e "${ENKFDIR}/prior_inf_d${DOMAIN}.1" || ! -e "${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1" ) then
    echo "ERROR: Inflation initialization did not produce both required files"
    exit 1
endif

/bin/cp -p "${ENKFDIR}/prior_inf_d${DOMAIN}.1" \
    "${RUNDIR}/${thisstart}/initial_prior_inf_d${DOMAIN}.1"
/bin/cp -p "${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1" \
    "${RUNDIR}/${thisstart}/initial_prior_inf_sd_d${DOMAIN}.1"

if ( $status != 0 ) then
    echo "ERROR: Cannot save initial inflation files"
    exit 1
endif

# ----------------------------------------------------------------------
# Run prior inflation
# ----------------------------------------------------------------------
if ( -e "${ENKFDIR}/prior_inf_done" ) then
    /bin/rm -f "${ENKFDIR}/prior_inf_done"
endif

set priorjob = "${ENKFDIR}/runpriorinf.job"

echo "#\!/bin/csh" >! "${priorjob}"
echo "#SBATCH -J runpriorinf" >> "${priorjob}"
echo "#SBATCH -o ${ENKFDIR}/runpriorinf.log.${thisstart}" >> "${priorjob}"
echo "#SBATCH -e ${ENKFDIR}/runpriorinf.err.${thisstart}" >> "${priorjob}"
echo "#SBATCH -p u1-compute" >> "${priorjob}"
echo "#SBATCH -q debug" >> "${priorjob}"
echo "#SBATCH --mem-per-cpu=6G" >> "${priorjob}"
echo "#SBATCH -n ${INF_CORES}" >> "${priorjob}"
echo "#SBATCH -t 00:10:00" >> "${priorjob}"

cat >> "${priorjob}" << EOF
module purge
module load intel-oneapi-compilers/2023.2.0
module load intel-oneapi-mpi/2021.13.1
module load intel-oneapi-mkl/2024.2.1
module load hdf5/1.14.3
module load parallel-netcdf/1.12.3
module load netcdf-c/4.9.2
module load netcdf-fortran/4.6.1

source ${GSIRLT}
source ${ENVFILE}
set echo
cd ${ENKFDIR}
ulimit -s unlimited

srun -n ${INF_CORES} ${RUNDIR}/GSI_RUN/prior_inf
if ( \$status == 0 ) then
    touch "${ENKFDIR}/prior_inf_done"
else
    echo "ERROR: prior_inf failed"
    exit 1
endif
exit 0
EOF

cd "${ENKFDIR}"
sbatch "${priorjob}"
if ( $status != 0 ) then
    echo "ERROR: Could not submit prior inflation job"
    exit 1
endif

while ( ! -e "${ENKFDIR}/prior_inf_done" )
    echo "WAITING FOR PRIOR INFLATION TO FINISH"
    sleep 3

    if ( -e "${ENKFDIR}/core" ) then
        ${MOVE} "${ENKFDIR}/core" "${RESULTSDIR}/stdout/core.priorinf.${thisstart}"
    endif
end

if ( ! -e "${ENKFDIR}/prior_inf_d${DOMAIN}.1" || ! -e "${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1" ) then
    echo "ERROR: Prior inflation output files are missing"
    exit 1
endif

/bin/cp -p "${ENKFDIR}/prior_inf_d${DOMAIN}.1" \
    "${RUNDIR}/${thisstart}/damped_prior_inf_d${DOMAIN}.1"
/bin/cp -p "${ENKFDIR}/prior_inf_sd_d${DOMAIN}.1" \
    "${RUNDIR}/${thisstart}/damped_prior_inf_sd_d${DOMAIN}.1"

if ( $status != 0 ) then
    echo "ERROR: Cannot save damped inflation files"
    exit 1
endif

echo "Prior inflation completed for ${datea}"
exit 0

