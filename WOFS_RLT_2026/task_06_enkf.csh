#!/bin/csh
#
########################################################################
#
#   task_06_enkf.csh
#
#   WoFS Ensemble Kalman Filter (EnKF) analysis task.
#
#   PURPOSE:
#     Run wrf_enkf for each data assimilation cycle.
#
#   PREREQUISITES:
#     - WoFS environment and event configuration are available.
#     - GSI/observation-processing tasks have completed.
#     - Ensemble wrfinput files and required diagnostic files exist.
#     - Prior inflation files exist when PRIOR_INF == 1.
#
########################################################################

set echo

if ( $#argv < 1 ) then
    echo "Usage: task_04_gsi.csh YYYYMMDDHHMM"
    exit 1
endif

set thisstart = "$argv[1]"
set datea = "$argv[1]"

# ----------------------------------------------------------------------
# SLURM ARRAY TASK ID
# ----------------------------------------------------------------------
if ( ! $?SLURM_ARRAY_TASK_ID ) then
    setenv SLURM_ARRAY_TASK_ID 1
endif

# ----------------------------------------------------------------------
# ENVIRONMENT
# ----------------------------------------------------------------------
source /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/module_list_intel_15_wps.csh

set GSIRLT = /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/WOFenv_rlt_2026
source ${GSIRLT}

set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
if ( ! -e ${ENVFILE} ) then
    echo "ERROR: Environment configuration not found: ${ENVFILE}"
    exit 1
endif
source ${ENVFILE}

# ----------------------------------------------------------------------
# ENKF DIRECTORIES
# Preserve the paths used by RUN_WOFS_RLT.csh.
# ----------------------------------------------------------------------
setenv ENKFDIR1 /scratch4/NCEPDEV/stmp/Hongli.Wang/wofs_wrf/wrf/obs/WOFSRun20261010-131148d1
setenv ENKFDIR2 /scratch4/NCEPDEV/stmp/Hongli.Wang/wofs_wrf/wrf/resources/enkf

# ----------------------------------------------------------------------
# TIME CONFIGURATION
# ----------------------------------------------------------------------
#set startdate = ${event}${cycle_start}00
#set datea = ${event}${cycle_start}00

# Override WOFS_DATE_END in the environment if needed.
if ( $?WOFS_DATE_END ) then
    set datef = ${WOFS_DATE_END}
else
    set datef = 202610110300
endif

echo "============================================================"
echo "WoFS task_06_enkf.csh"
echo "Event       : ${event}"
echo "Start time  : ${datea}"
echo "End time    : ${datef}"
echo "EnKF dir    : ${ENKFDIR}"
echo "Ensemble    : ${ENS_SIZE}"
echo "============================================================"

# ----------------------------------------------------------------------
# CHECK REQUIRED DIRECTORIES AND FILES
# ----------------------------------------------------------------------
if ( ! -d ${RUNDIR} ) then
    echo "ERROR: RUNDIR does not exist: ${RUNDIR}"
    exit 1
endif

if ( ! -d ${ENKFDIR} ) then
    mkdir -p ${ENKFDIR}
    if ( $status != 0 ) then
        echo "ERROR: Cannot create ${ENKFDIR}"
        exit 1
    endif
endif

if ( ! -d ${RESULTSDIR} ) then
    mkdir -p ${RESULTSDIR}
endif

if ( ! -d ${RESULTSDIR}/stdout ) then
    mkdir -p ${RESULTSDIR}/stdout
endif

if ( ! -e ${TEMPLATE_DIR}/enkf.nml.template ) then
    echo "ERROR: Missing EnKF namelist template:"
    echo "${TEMPLATE_DIR}/enkf.nml.template"
    exit 1
endif

if ( ! -x ${RUNDIR}/GSI_RUN/wrf_enkf ) then
    echo "ERROR: wrf_enkf executable not found or not executable:"
    echo "${RUNDIR}/GSI_RUN/wrf_enkf"
    exit 1
endif

if ( ! -x ${RUNDIR}/advance_time ) then
    echo "ERROR: advance_time executable is unavailable."
    exit 1
endif

cd ${RUNDIR}

# ----------------------------------------------------------------------
# MAIN LOOP OVER ASSIMILATION CYCLES
# ----------------------------------------------------------------------
#while ( 1 == 1 )

    echo "============================================================"
    echo "Starting EnKF analysis at ${datea}"
    echo "============================================================"

    # Calculate the next cycle time.
    set daten = `echo ${datea} ${cycleinterval}m | ${RUNDIR}/advance_time`

    set thisstart = ${datea}
    set thisend = ${daten}

    set startyear  = `echo ${thisstart} | cut -c1-4`
    set startmonth = `echo ${thisstart} | cut -c5-6`
    set startday   = `echo ${thisstart} | cut -c7-8`
    set starthour  = `echo ${thisstart} | cut -c9-10`
    set startmin   = `echo ${thisstart} | cut -c11-12`

    set endyear  = `echo ${thisend} | cut -c1-4`
    set endmonth = `echo ${thisend} | cut -c5-6`
    set endday   = `echo ${thisend} | cut -c7-8`
    set endhour  = `echo ${thisend} | cut -c9-10`
    set endmin   = `echo ${thisend} | cut -c11-12`

    # Per-cycle diagnostic directory.
    set DOMAIN = 01
    set CYCLEDIR = ${RUNDIR}/${thisstart}
    set DIAGDIR = ${CYCLEDIR}/diag_${DOMAIN}

    if ( ! -d ${CYCLEDIR} ) then
        echo "Cycle directory does not exist: ${CYCLEDIR}"
        echo "Make DIR: ${CYCLEDIR}"
        mkdir -p ${CYCLEDIR} 
    endif

    if ( ! -d ${DIAGDIR} ) then
        mkdir -p ${DIAGDIR}
    endif

    # --------------------------------------------------------------
    # VERIFY ENSEMBLE INPUTS
    # --------------------------------------------------------------
    set imem = 1
    while ( ${imem} <= ${ENS_SIZE} )

        if ( ! -e ${ENKFDIR}/wrfinput_d01.${imem} ) then
            echo "ERROR: Missing ensemble input:"
            echo "${ENKFDIR}/wrfinput_d01.${imem}"
            echo "Check the preceding forecast/analysis task."
            exit 1
        endif

        @ imem++
    end

    # Verify the GSI diagnostic products required by wrf_enkf.
    # The original workflow stores member work directories as gsiN.
    set imem = 1
    while ( ${imem} <= ${ENS_SIZE} )

        if ( ! -d ${ENKFDIR}/gsi${imem} ) then
            echo "ERROR: Missing GSI member directory:"
            echo "${ENKFDIR}/gsi${imem}"
            exit 1
        endif

        if ( ! -e ${ENKFDIR}/gsi${imem}/gsi_done ) then
            echo "ERROR: GSI completion flag missing for member ${imem}"
            echo "Expected ${ENKFDIR}/gsi${imem}/gsi_done"
            exit 1
        endif

        @ imem++
    end

    # --------------------------------------------------------------
    # LINK BOUNDARY CONDITIONS
    # --------------------------------------------------------------
    set imem = 1
    while ( ${imem} <= ${ENS_SIZE} )

        if ( ! -e ${RUNDIR}/mem${imem}/wrfbdy_d01.${imem} ) then
            echo "WARNING: Boundary file not found for member ${imem}"
        else
            ln -sf ${RUNDIR}/mem${imem}/wrfbdy_d01.${imem} \
                ${ENKFDIR}/wrfbdy_d01.${imem}
        endif

        @ imem++
    end

    # --------------------------------------------------------------
    # CREATE ENKF NAMELIST
    # Use the same parameter names as RUN_WOFS_RLT.csh.
    # --------------------------------------------------------------
    if ( ! $?ANALPERTWTNH3KM || ! $?ANALPERTWTSH || \
         ! $?ANALPERTWTTR || ! $?CORRLENGTHNH || \
         ! $?CORRLENGTHSH || ! $?CORRLENGTHTR || \
         ! $?LNSIGCUTOFFNH || ! $?LNSIGCUTOFFSH || \
         ! $?LNSIGCUTOFFTR || ! $?LNSIGCUTOFFPSNH || \
         ! $?LNSIGCUTOFFPSSH || ! $?LNSIGCUTOFFPSTR || \
         ! $?NLONS || ! $?NLATS || ! $?NLEVS || \
         ! $?NANALS || ! $?NVARS || ! $?PRIOR_INF ) then
        echo "ERROR: One or more required EnKF parameters are unset."
        echo "Check realtime.cfg.${event} and the WoFS environment."
        exit 1
    endif

    ${REMOVE} ${ENKFDIR}/enkf.sed
    ${REMOVE} ${ENKFDIR}/enkf.nml.temp

    cat >! ${ENKFDIR}/enkf.sed << EOF
/datestring=/c\\
datestring="${datea}",
/datapath=/c\\
datapath="${ENKFDIR}/",
/analpertwtnh=/c\\
analpertwtnh=${ANALPERTWTNH3KM},
/analpertwtsh=/c\\
analpertwtsh=${ANALPERTWTSH},
/analpertwttr=/c\\
analpertwttr=${ANALPERTWTTR}
/analpertwttr=/c\
analpertwttr=${ANALPERTWTTR},
/corrlengthnh=/c\
corrlengthnh=${CORRLENGTHNH},
/corrlengthsh=/c\
corrlengthsh=${CORRLENGTHSH},
/corrlengthtr=/c\
corrlengthtr=${CORRLENGTHTR},
/lnsigcutoffnh=/c\
lnsigcutoffnh=${LNSIGCUTOFFNH},
/lnsigcutoffsh=/c\
lnsigcutoffsh=${LNSIGCUTOFFSH},
/lnsigcutofftr=/c\
lnsigcutofftr=${LNSIGCUTOFFTR},
/lnsigcutoffpsnh=/c\
lnsigcutoffpsnh=${LNSIGCUTOFFPSNH},
/lnsigcutoffpssh=/c\
lnsigcutoffpssh=${LNSIGCUTOFFPSSH},
/lnsigcutoffpstr=/c\
lnsigcutoffpstr=${LNSIGCUTOFFPSTR},
/nlons=/c\
nlons=${NLONS},
/nlats=/c\
nlats=${NLATS},
/nlevs=/c\
nlevs=${NLEVS},
/nanals=/c\
nanals=${NANALS},
/nvars=/c\
nvars=${NVARS},
/prior_inf=/c\
prior_inf=${PRIOR_INF},
/fgfileprefixes =/c\
fgfileprefixes = 'wrfinput_d${DOMAIN}.','','','','','','',
/anlfileprefixes =/c\
anlfileprefixes = 'wrfinput_d${DOMAIN}.','','','','','','',
/prior_inf_file =/c\
prior_inf_file = 'prior_inf_d${DOMAIN}',
/prior_inf_sd_file =/c\
prior_inf_sd_file = 'prior_inf_sd_d${DOMAIN}',
EOF

    # Generate the EnKF namelist.
    cp -p ${TEMPLATE_DIR}/enkf.nml.template \
        ${ENKFDIR}/enkf.nml.temp

    sed -f ${ENKFDIR}/enkf.sed \
        ${ENKFDIR}/enkf.nml.temp >! ${ENKFDIR}/enkf.nml

    if ( $status != 0 ) then
        echo "ERROR: Failed to generate enkf.nml"
        exit 1
    endif

    if ( ! -s ${ENKFDIR}/enkf.nml ) then
        echo "ERROR: Generated enkf.nml is empty"
        exit 1
    endif

    # --------------------------------------------------------------
    # RUN ENKF
    # --------------------------------------------------------------
    echo "Preparing to run wrf_enkf for ${datea}"

    # Remove stale completion flags before submitting the job.
    ${REMOVE} ${ENKFDIR}/enkf_done
    ${REMOVE} ${ENKFDIR}/runenkf.job
    ${REMOVE} ${ENKFDIR}/core

    cat >! ${ENKFDIR}/runenkf.job << EOF
#!/bin/csh
#SBATCH -J runenkf
#SBATCH -o ${ENKFDIR}/runenkf.log.${thisstart}
#SBATCH -e ${ENKFDIR}/runenkf.err.${thisstart}
#SBATCH -p u1-compute
#SBATCH -q debug
#SBATCH --exclusive
#SBATCH -n ${EKF_CORES}
#SBATCH -t 00:15:00

module purge
module load intel-oneapi-compilers/2023.2.0
module load intel-oneapi-mpi/2021.13.1
module load intel-oneapi-mkl/2024.2.1
module load hdf5/1.14.3
module load netcdf-c/4.9.2
module load netcdf-fortran/4.6.1

source ${GSIRLT}
source ${ENVFILE}

cd ${ENKFDIR}
ulimit -s unlimited

srun --mpi=pmi2 -n ${EKF_CORES} ${RUNDIR}/GSI_RUN/wrf_enkf
set rc = \$status

if ( \$rc == 0 && -s ${ENKFDIR}/allobs_enkf ) then
    touch ${ENKFDIR}/enkf_done
else
    echo "ERROR: wrf_enkf failed or allobs_enkf is missing"
    exit 1
endif

exit 0
EOF

    # Submit EnKF and wait for completion.
    set enkf_attempt = 0
    set enkf_complete = 0

    while ( ${enkf_attempt} < 3 && ${enkf_complete} == 0 )

        @ enkf_attempt++
        ${REMOVE} ${ENKFDIR}/enkf_done
        ${REMOVE} ${ENKFDIR}/core

        echo "Submitting EnKF attempt ${enkf_attempt} for ${datea}"
        cd ${ENKFDIR}
        sbatch ${ENKFDIR}/runenkf.job

        set waited = 0

        while ( ! -e ${ENKFDIR}/enkf_done && ${waited} < 180 )
            sleep 5
            @ waited++

            if ( -e ${ENKFDIR}/core ) then
                echo "WARNING: EnKF core file detected"
                break
            endif
        end

        if ( -e ${ENKFDIR}/enkf_done && \
             -s ${ENKFDIR}/allobs_enkf ) then
            set enkf_complete = 1
        else
            echo "WARNING: EnKF attempt ${enkf_attempt} failed or timed out"
            ${REMOVE} ${ENKFDIR}/enkf_done
            ${REMOVE} ${ENKFDIR}/core

            if ( ${enkf_attempt} < 3 ) then
                echo "Retrying EnKF after 10 seconds"
                sleep 10
            endif
        endif

    end

    if ( ${enkf_complete} == 0 ) then
        echo "ERROR: EnKF failed after 3 attempts at ${datea}"
        echo "Inspect ${ENKFDIR}/runenkf.log.${thisstart}"
        echo "Inspect ${ENKFDIR}/runenkf.err.${thisstart}"
        exit 1
    endif

    echo "EnKF completed successfully for ${datea}"

    # --------------------------------------------------------------
    # SAVE OUTPUTS
    # --------------------------------------------------------------
    set OBSOUT = ${RESULTSDIR}/allobs_enkf_d${DOMAIN}.${thisstart}

    if ( -e ${OBSOUT} ) then
        echo "WARNING: Replacing existing ${OBSOUT}"
        ${REMOVE} ${OBSOUT}
    endif

    ${MOVE} ${ENKFDIR}/allobs_enkf ${OBSOUT}

    if ( ! -e ${OBSOUT} ) then
        echo "ERROR: Failed to save EnKF observation output"
        exit 1
    endif

    # Save diagnostic files for this cycle.
    foreach diagfile ( ${ENKFDIR}/diag* )
        if ( -e ${diagfile} ) then
            ${MOVE} ${diagfile} ${DIAGDIR}/
        endif
    end

    # Save analyzed ensemble members.
    # Support both single-digit and multi-digit member numbers.
    set imem = 1

    while ( ${imem} <= ${ENS_SIZE} )

        set analysisfile = ${ENKFDIR}/wrfinput_d01.${imem}

        if ( -e ${analysisfile} ) then
            ${MOVE} ${analysisfile} ${CYCLEDIR}/
        else
            echo "ERROR: Analyzed member file missing: ${analysisfile}"
            exit 1
        endif

        @ imem++
    end

    # Archive EnKF logs.
    foreach logfile ( ${ENKFDIR}/runenkf.log.${thisstart} \
                      ${ENKFDIR}/runenkf.err.${thisstart} )
        if ( -e ${logfile} ) then
            ${MOVE} ${logfile} ${RESULTSDIR}/stdout/
        endif
    end

    # --------------------------------------------------------------
    # SIGNAL FORECAST READINESS
    # --------------------------------------------------------------
    if ( ! -d ${FCST_DIR} ) then
        echo "ERROR: Forecast directory does not exist: ${FCST_DIR}"
        exit 1
    endif

    touch ${FCST_DIR}/analysis_${datea}_done

    echo "Forecast readiness flag created:"
    echo "${FCST_DIR}/analysis_${datea}_done"

    # --------------------------------------------------------------
    # ADVANCE TO NEXT ASSIMILATION CYCLE
    # --------------------------------------------------------------
    if ( "${datea}" == "${datef}" ) then
        echo "Reached final analysis time ${datef}"
        echo "task_06_enkf.csh completed successfully"
        break
    endif

    set nextdate = `echo ${datea} ${cycleinterval}m | ${RUNDIR}/advance_time`

    if ( $status != 0 || "${nextdate}" == "${datea}" ) then
        echo "ERROR: Unable to advance assimilation time from ${datea}"
        exit 1
    endif

    if ( "${nextdate}" > "${datef}" ) then
        echo "ERROR: Next cycle ${nextdate} exceeds final time ${datef}"
        echo "Check WOFS_DATE_END and cycleinterval."
        exit 1
    endif

    set datea = ${nextdate}
    echo "Starting next EnKF cycle at ${datea}"

#end

echo "============================================================"
echo "task_06_enkf.csh finished"
echo "============================================================"

exit 0

