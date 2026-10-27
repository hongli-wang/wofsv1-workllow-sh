#!/bin/csh
#
########################################################################
#
#   TASK 08: FINALIZE WoFS DATA ASSIMILATION CYCLE
#
#   Responsibilities:
#     1. Verify that all ensemble members have completed WRF advancement.
#     2. Clean up member working-directory logs.
#     WOFS_RLT_2026/task_06_enkf.csh :3. Save additive-noise diagnostics.
#     task_prior: 4. Calculate the ensemble-mean reflectivity forecast.
#     5. Collect diagnostic files and generate CFL logs.
#     6. Exit at datef or advance datea to the next cycle.
#
########################################################################

# Enable command echoing for debugging.
set echo
set verbose
#unset echo
#unset verbose

########################################################################
# CHECK REQUIRED ENVIRONMENT
########################################################################

if ( ! $?SLURM_ARRAY_TASK_ID ) then
    setenv SLURM_ARRAY_TASK_ID 1
endif

if ( ! $?RUNDIR || ! $?ENKFDIR || ! $?RESULTSDIR || ! $?SCRIPTDIR ) then
    echo "ERROR: Required environment variables are not defined."
    exit 1
endif

if ( ! $?ENS_SIZE || ! $?datea || ! $?datef ) then
    echo "ERROR: ENS_SIZE, datea, or datef is not defined."
    exit 1
endif

cd ${RUNDIR}
if ( $status != 0 ) then
    echo "ERROR: Cannot enter RUNDIR: ${RUNDIR}"
    exit 1
endif

########################################################################
# VALIDATE CYCLE VARIABLES
########################################################################

set thisstart = ${datea}

echo "============================================================"
echo "TASK 08: FINALIZE CYCLE"
echo "Current analysis time: ${datea}"
echo "Final analysis time:   ${datef}"
echo "Ensemble size:         ${ENS_SIZE}"
echo "============================================================"

########################################################################
# WAIT FOR ALL ENSEMBLE MEMBERS TO FINISH
########################################################################

set imem = 1
set member_failed = 0

while ( ${imem} <= ${ENS_SIZE} )

    set donefile = ${RUNDIR}/adv_wrf_done${imem}
    set ccc = 0

    while ( ! -e "${donefile}" )

        echo "WAITING FOR MEMBER ${imem} TO FINISH"
        echo "Expected completion flag: ${donefile}"

        sleep 3
        @ ccc++

        # Do not wait indefinitely. Tune this timeout for your workload.
        if ( ${ccc} >= 1200 ) then
            echo "ERROR: MEMBER ${imem} DID NOT COMPLETE WITHIN THE TIMEOUT."
            set member_failed = 1
            break
        endif

    end

    if ( ! -e "${donefile}" ) then
        echo "ERROR: Completion flag missing for member ${imem}"
        set member_failed = 1
    else
        echo "MEMBER ${imem} COMPLETION FLAG FOUND"
    endif

    @ imem++

end

if ( ${member_failed} != 0 ) then
    echo "ERROR: One or more ensemble members did not complete."
    echo "Preserving intermediate files for diagnosis."
    exit 1
endif

########################################################################
# VERIFY EXPECTED WRF OUTPUTS
#
# The completion flags alone do not guarantee that every output file
# exists. Verify the forecast output for each member before proceeding.
########################################################################

set imem = 1
set member_failed = 0

while ( ${imem} <= ${ENS_SIZE} )

    set memout = ${ENKFDIR}/wrfinput_d01.${imem}

    if ( ! -e "${memout}" ) then
        echo "ERROR: Expected updated member file is missing:"
        echo "       ${memout}"
        set member_failed = 1
    endif

    @ imem++

end

if ( ${member_failed} != 0 ) then
    echo "ERROR: Updated member files are missing."
    exit 1
endif
exit 0 

########################################################################
# CLEAN UP MEMBER WORKING-DIRECTORY LOGS
########################################################################

set imem = 1

while ( ${imem} <= ${ENS_SIZE} )

    set memdir = ${RUNDIR}/enkfrun${imem}

    if ( -d "${memdir}" ) then

        # Remove temporary rsl logs only when they exist.
        set stale_logs = ( "${memdir}"/rsl* )

        if ( -e "${stale_logs[1]}" ) then
            ${REMOVE} "${memdir}"/rsl*
        endif

    else
        echo "WARNING: Member working directory not found: ${memdir}"
    endif

    @ imem++

end

exit 0
########################################################################
# SAVE REFLECTIVITY OBSERVATION DIAGNOSTICS
########################################################################
#/task_07_advance_members.csh:        ${MOVE} "${ENKFDIR}/refl_obs.txt"
if ( -e ${ENKFDIR}/refl_obs.txt ) then

    if ( ! -d ${RESULTSDIR}/stdout ) then
        mkdir -p ${RESULTSDIR}/stdout
    endif

    ${MOVE} ${ENKFDIR}/refl_obs.txt \
        ${RESULTSDIR}/stdout/refl_obs_${thisstart}.txt

    if ( $status != 0 ) then
        echo "WARNING: Could not move refl_obs.txt"
    endif

else
    echo "WARNING: ${ENKFDIR}/refl_obs.txt not found"
endif

exit 0

########################################################################
# CALCULATE ENSEMBLE-MEAN REFLECTIVITY FORECAST
#
# Reuse the original Slurm job and its existing resource settings.
########################################################################

cd ${ENKFDIR}
if ( $status != 0 ) then
    echo "ERROR: Cannot enter ENKFDIR: ${ENKFDIR}"
    exit 1
endif

if ( ! -e ${SCRIPTDIR}/run_nceamean_conv_d01.job ) then
    echo "ERROR: Ensemble-mean job file is missing:"
    echo "       ${SCRIPTDIR}/run_nceamean_conv_d01.job"
    exit 1
endif

# Remove a stale completion flag only if it exists.
if ( -e ${ENKFDIR}/ensmean_done01 ) then
    ${REMOVE} ${ENKFDIR}/ensmean_done01
endif

${COPY} ${SCRIPTDIR}/run_nceamean_conv_d01.job \
        ${ENKFDIR}/run_nceamean_conv_d01.job

if ( $status != 0 ) then
    echo "ERROR: Could not stage run_nceamean_conv_d01.job"
    exit 1
endif

echo "Submitting ensemble-mean reflectivity job"
sbatch ${ENKFDIR}/run_nceamean_conv_d01.job

if ( $status != 0 ) then
    echo "ERROR: Failed to submit ensemble-mean job"
    exit 1
endif

set ccc = 0

while ( ! -e ${ENKFDIR}/ensmean_done01 )

    echo "WAITING FOR ENSEMBLE MEAN TO FINISH"
    sleep 3
    @ ccc++

    if ( ${ccc} >= 1200 ) then
        echo "ERROR: Ensemble-mean job timed out."
        exit 1
    endif

end

echo "ENSEMBLE MEAN COMPLETED"

########################################################################
# COLLECT DIAGNOSTIC FILES
########################################################################

if ( ! -d ${RUNDIR}/${thisstart} ) then
    mkdir -p ${RUNDIR}/${thisstart}
endif

# Move diagnostics only if matching files exist.
set diag_files = ( ${ENKFDIR}/diag* )

if ( -e "${diag_files[1]}" ) then

    ${MOVE} ${ENKFDIR}/diag* ${RUNDIR}/${thisstart}/

    if ( $status != 0 ) then
        echo "WARNING: Could not move all diagnostic files"
    endif

else
    echo "WARNING: No diagnostic files found in ${ENKFDIR}"
endif

########################################################################
# GENERATE CFL LOG
########################################################################

cd ${RUNDIR}
if ( $status != 0 ) then
    echo "ERROR: Cannot return to RUNDIR: ${RUNDIR}"
    exit 1
endif

set cfl_files = ( ${RUNDIR}/enkfrun*/rsl* )

if ( -e "${cfl_files[1]}" ) then

    grep cfl ${RUNDIR}/enkfrun*/rsl* >! \
        ${RUNDIR}/cfl.log.${thisstart}

    echo "CFL diagnostic log written:"
    echo "${RUNDIR}/cfl.log.${thisstart}"

else
    echo "WARNING: No RSL files available for CFL diagnostics"
endif

