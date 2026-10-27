#!/bin/csh
#
# task_05_diagnostics.csh
# Calculate ensemble-mean GSI innovations.
#
# Usage:
#   ./task_05_diagnostics.csh YYYYMMDDHHMM
#

if ( $#argv < 1 ) then
    echo "Usage: task_05_diagnostics.csh YYYYMMDDHHMM"
    exit 1
endif

set datea = "$argv[1]"

source /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/module_list_intel_15_wps.csh

set GSIRLT = /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/WOFenv_rlt_2026
source ${GSIRLT}

set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
source ${ENVFILE}

cd "${ENKFDIR}"
if ( $status != 0 ) then
    echo "ERROR: Cannot enter ENKFDIR"
    exit 1
endif

# Verify the diagnostic executables and job templates.
if ( ! -e "${GSIDIR}/util/Analysis_Utilities/read_diag/innov_mean_conv.exe" ) then
    echo "ERROR: Missing innov_mean_conv.exe"
    exit 1
endif

if ( ! -e "${SCRIPTDIR}/run_diagmean.job" ) then
    echo "ERROR: Missing ${SCRIPTDIR}/run_diagmean.job"
    exit 1
endif

if ( ! -e "${TEMPLATE_DIR}/namelist.innov.template" ) then
    echo "ERROR: Missing namelist.innov.template"
    exit 1
endif

/bin/cp -p "${GSIDIR}/util/Analysis_Utilities/read_diag/innov_mean_conv.exe" .
/bin/cp -p "${GSIDIR}/util/Analysis_Utilities/read_diag/innov_mean_radiance.exe" .
/bin/cp -p "${SCRIPTDIR}/run_diagmean.job" .
/bin/cp -p "${SCRIPTDIR}/run_diagmean_rad.job" .

# Generate the conventional innovation namelist.
cat >! advModel.sed << EOF
/nmem/c\\
 nmem  = ${ENS_SIZE},
EOF

sed -f advModel.sed "${TEMPLATE_DIR}/namelist.innov.template" >! namelist.innov

# Generate the radiance namelist, retaining the template from the driver.
if ( -e "${TEMPLATE_DIR}/namelist.innov.rad.template.g16" ) then
    sed -f advModel.sed "${TEMPLATE_DIR}/namelist.innov.rad.template.g16" >! namelist.innov.rad
endif

# Clear only the completion flags belonging to these diagnostic jobs.
if ( -e diagmean_done ) then
    /bin/rm -f diagmean_done
endif
if ( -e diagmeanrad_done ) then
    /bin/rm -f diagmeanrad_done
endif

# Run conventional diagnostic mean.
sbatch run_diagmean.job
if ( $status != 0 ) then
    echo "ERROR: Could not submit run_diagmean.job"
    exit 1
endif

while ( ! -e diagmean_done )
    echo "WAITING FOR DIAG MEAN CONV TO FINISH"
    sleep 2
end

# Run radiance diagnostics only if the ensemble radiance diagnostics exist.
if ( -e diag_abi_g16_ges.mem001 ) then
    sbatch run_diagmean_rad.job
    if ( $status != 0 ) then
        echo "ERROR: Could not submit run_diagmean_rad.job"
        exit 1
    endif

    while ( ! -e diagmeanrad_done )
        echo "WAITING FOR DIAG MEAN RAD TO FINISH"
        sleep 2
    end
endif

echo "Diagnostic mean processing completed for ${datea}"
exit 0

