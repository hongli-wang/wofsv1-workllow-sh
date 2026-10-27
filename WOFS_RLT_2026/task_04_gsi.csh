#!/bin/csh -f 
# task_04_gsi.csh
#
# Usage:
#   ./task_04_gsi.csh YYYYMMDDHHMM
#
# Creates and submits the GSI ensemble-member array, waits for completion,
# and collects conventional diagnostic files.

if ( $#argv < 1 ) then
    echo "Usage: task_04_gsi.csh YYYYMMDDHHMM"
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

cd "${ENKFDIR}"
if ( $status != 0 ) then
    echo "ERROR: Cannot enter ENKFDIR: ${ENKFDIR}"
    exit 1
endif

#if ( ! -e "${ENKFDIR}/gsiparm.anl" ) then
#    echo "ERROR: gsiparm.anl missing. Run task_03_observations.csh first."
#    exit 1
#endif

if ( -e "${ENKFDIR}/gsiparm.anl" ) then
    echo "Found gsiparm.anl"
else
    echo "ERROR: gsiparm.anl missing. Run task_03_observations.csh first."
    exit 1
endif

# ----------------------------------------------------------------------
# Generate the GSI Slurm job
# ----------------------------------------------------------------------
rm -fr  "${ENKFDIR}/run_gsi_mem.job"
touch "${ENKFDIR}/run_gsi_mem.job"
set gsijob = "${ENKFDIR}/run_gsi_mem.job"

echo "#\!/bin/csh" >! "${gsijob}"
echo "#==================================================================" >> "${gsijob}"
echo '#SBATCH -J run_gsi_mem' >> "${gsijob}"
echo "#SBATCH -o ${ENKFDIR}/run_gsi%a.log" >> "${gsijob}"
echo "#SBATCH -e ${ENKFDIR}/run_gsi%a.err" >> "${gsijob}"
echo "#SBATCH -p u1-compute" >> "${gsijob}"
echo "#SBATCH -q debug" >> "${gsijob}"
echo "#SBATCH --mem=300G" >> "${gsijob}"
echo "#SBATCH -n ${GSI_CORES}" >> "${gsijob}"
echo "#SBATCH -t 0:10:00" >> "${gsijob}"
echo "#==================================================================" >> "${gsijob}"

cat >> "${gsijob}" << EOF
module purge
module load intel-oneapi-compilers/2023.2.0
module load intel-oneapi-mpi/2021.13.1
module load intel-oneapi-mkl/2024.2.1
module load hdf5/1.14.3
module load netcdf-c/4.9.2
module load netcdf-fortran/4.6.1

source ${GSIRLT}
source ${ENVFILE}

set echo
ulimit -s unlimited

set memdir = "${ENKFDIR}/gsi\${SLURM_ARRAY_TASK_ID}"

echo "Create working directory: \$memdir"

if ( -d "\$memdir" ) then
    /bin/rm -rf "\$memdir"
endif

mkdir -p "\$memdir"
if ( \$status != 0 ) then
    echo "ERROR: Cannot create \$memdir"
    exit 1
endif

cd "\$memdir"
if ( \$status != 0 ) then
    echo "ERROR: Cannot enter \$memdir"
    exit 1
endif

# Member background
#/scratch4/NCEPDEV/stmp/Hongli.Wang/wofs/realtime/20261010/202610101500/wrfout_d01_2026-10-10_15:00:00_1
if ( ! -e "${ENKFDIR}/wrfinput_d01.\${SLURM_ARRAY_TASK_ID}" ) then
#if ( ! -e "/scratch4/NCEPDEV/stmp/Hongli.Wang/wofs/realtime/20261010/202610101500/wrfout_d01_2026-10-10_15:00:00_\${SLURM_ARRAY_TASK_ID}" ) then
    echo "ERROR: Missing member background for member \${SLURM_ARRAY_TASK_ID}"
    exit 1
endif

ln -sf "${ENKFDIR}/wrfinput_d01.\${SLURM_ARRAY_TASK_ID}" ./wrf_inout
#ln -sf "/scratch4/NCEPDEV/stmp/Hongli.Wang/wofs/realtime/20261010/202610101500/wrfout_d01_2026-10-10_15:00:00_\${SLURM_ARRAY_TASK_ID}" ./wrf_inout
/bin/cp -pv "${ENKFDIR}/gsiparm.anl" ./gsiparm.anl

set timestr = \`echo ${datea} | cut -c9-12\`
set fulltime = ${datea}

set obsdir1 = ${ENKFDIR1}/${event}\${timestr}
set obsdir2 = ${ENKFDIR1}/\${fulltime}

# ----------------------------------------------------------------------
# Optional observation files
# ----------------------------------------------------------------------

# GOES
if ( -e "\${obsdir1}/\${timestr}-goes.nc" ) then
    /bin/cp -pv "\${obsdir1}/\${timestr}-goes.nc" ./goes.nc
else if ( -e "\${obsdir2}/\${timestr}-goes.nc" ) then
    /bin/cp -pv "\${obsdir2}/\${timestr}-goes.nc" ./goes.nc
else
    echo "WARNING: GOES file not found for \${timestr}"
endif

# DBZ
if ( -e "\${obsdir1}/\${timestr}-dbzobs.nc" ) then
    /bin/cp -pv "\${obsdir1}/\${timestr}-dbzobs.nc" ./dbzobs.nc
else if ( -e "\${obsdir2}/\${timestr}-dbzobs.nc" ) then
    /bin/cp -pv "\${obsdir2}/\${timestr}-dbzobs.nc" ./dbzobs.nc
else
    echo "WARNING: DBZ file not found for \${timestr}"
endif

# CWP
if ( -e "\${obsdir1}/\${timestr}-cwpobs.nc" ) then
    /bin/cp -pv "\${obsdir1}/\${timestr}-cwpobs.nc" ./cwpobs.nc
else if ( -e "\${obsdir2}/\${timestr}-cwpobs.nc" ) then
    /bin/cp -pv "\${obsdir2}/\${timestr}-cwpobs.nc" ./cwpobs.nc
else
    echo "WARNING: CWP file not found for \${timestr}"
endif

# Fixed GSI input files

ln -sf "${ENKFDIR}/satbias_angle" .
ln -sf "${ENKFDIR}/satinfo" . 
ln -sf  "${ENKFDIR}/ozinfo" . 
ln -sf  "${ENKFDIR}/satbias_in" . 
ln -sf  "${ENKFDIR}/satbias_pc" . 
ln -sf   "${ENKFDIR}/convinfo" . 

/bin/cp -pv "${ANAVINFO}" . 
/bin/cp -pv "${OBERROR}"  ./errtable 
/bin/cp -pv "${BERROR}" ./berror_stats

# Link CRTM coefficient files. Use find so absent wildcard matches
# do not trigger csh's "No match" error.
foreach pattern ( "AerosolCoeff.bin" "CloudCoeff.bin" "NPOESS.*" "USGS.*" "FAST*" "MWwaterLUT.bin" "Nalli.IRwater.EmisCoeff.bin" "WuSmith.IRwater.EmisCoeff.bin" "abi*" )
    find "${CRTM_DIR}" -maxdepth 1 -name "\$pattern" -exec /bin/ln -sf {} . \\;
end

sleep 1
ulimit -s unlimited

# ----------------------------------------------------------------------
# Run GSI
# ----------------------------------------------------------------------
srun --mpi=pmi2 -n ${GSI_CORES} ${RUNDIR}/GSI_RUN/gsi.exe > "${ENKFDIR}/run_gsi.mem\${SLURM_ARRAY_TASK_ID}_${datea}.log"

set gsi_status = \$status
sleep 1

if ( \$gsi_status != 0 ) then
    echo "ERROR: GSI executable failed for member \${SLURM_ARRAY_TASK_ID}"
    exit 1
endif

if ( -e pe0001.conv_01 ) then
    sleep 8
    cat pe*conv_01* > ./diag_conv_ges.tmp

    if ( -e diag_conv_ges.tmp ) then
        touch gsi_done
        exit 0
    endif
endif

echo "ERROR: GSI conventional diagnostics missing for member \${SLURM_ARRAY_TASK_ID}"
exit 1
EOF

# ----------------------------------------------------------------------
# Remove stale per-member completion flags safely
# ----------------------------------------------------------------------
find "${ENKFDIR}" -maxdepth 2 -type f -path "${ENKFDIR}/gsi*/gsi_done" \
    -exec /bin/rm -f {} \;

# ----------------------------------------------------------------------
# Submit all members
# ----------------------------------------------------------------------
cd "${ENKFDIR}"
sbatch --array=1-${ENS_SIZE} "${gsijob}"
#sbatch --array=1-2 "${gsijob}"

if ( $status != 0 ) then
    echo "ERROR: Could not submit GSI member array"
    exit 1
endif

# ----------------------------------------------------------------------
# Wait for all members; retry individual members after timeout
# ----------------------------------------------------------------------
set imem = 1

while ( ${imem} <= ${ENS_SIZE} )

    set ccc = 1

    if ( ${imem} < 100 ) then
        set mem = 0${imem}
    else
        set mem = ${imem}
    endif

    if ( ${imem} < 10 ) then
        set mem = 00${imem}
    endif

    while ( ! -e "${ENKFDIR}/gsi${imem}/gsi_done" )

        echo "WAITING FOR GSI MEMBER ${imem} TO FINISH ${ccc}"
        sleep 3

        if ( ${ccc} > 120 ) then
            echo "GSI FOR MEMBER ${imem} NOT COMPLETED -- RESUBMITTING"

            # Remove the failed member's completion flag, if present.
            if ( -e "${ENKFDIR}/gsi${imem}/gsi_done" ) then
                /bin/rm -f "${ENKFDIR}/gsi${imem}/gsi_done"
            endif

            sbatch --array=${imem}-${imem} "${gsijob}"
            if ( $status != 0 ) then
                echo "ERROR: Failed to resubmit GSI member ${imem}"
                exit 1
            endif

            sleep 20
            set ccc = 1
        endif

        @ ccc++
    end

    echo "GSI FOR MEMBER ${imem} FINISHED"

    if ( -e "${ENKFDIR}/gsi${imem}/diag_conv_ges.tmp" ) then
        /bin/cp -p "${ENKFDIR}/gsi${imem}/diag_conv_ges.tmp" \
            "${ENKFDIR}/diag_conv_ges.mem${mem}"
    else
        echo "ERROR: Missing conventional diagnostics for member ${imem}"
        exit 1
    endif

    @ imem++
end

echo "All GSI members completed for ${datea}"
exit 0

