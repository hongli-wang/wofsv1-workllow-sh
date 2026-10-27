#!/bin/csh -f
#
# DRIVER_MAIN_WoFS_v3.csh
# Main WoFS real-time cycling driver
#
# Stage switches:
#   1 = run stage; 0 = skip stage
#   .true. / true = run stage
#   .false. / false = skip stage
#
########################################################################

set echo
set verbose
#unset echo
#unset verbose

#----------------------------------------------------------
# 0. USER-CONTROLLED STAGE SWITCHES
#----------------------------------------------------------
# Set each switch to 1 or .true. to execute the stage.
# Set each switch to 0 or .false. to skip the stage.
#
# Defaults: all stages enabled.
#----------------------------------------------------------

# Cold-start controls.
set firstcycle_coldstart = .true.
set firstcycle_coldstart_done = .false.

set run_stage_1 = 1     # Prior inflation
set run_stage_2 = 1     # Observation processing
set run_stage_3 = 1     # GSI ensemble analysis
set run_stage_4 = 1     # Ensemble-mean diagnostics
set run_stage_5 = 1     # EnKF data assimilation
set run_stage_6 = 1     # Advance WRF ensemble members
set run_stage_7 = 1     # Finalize cycle

#----------------------------------------------------------
# 0a. NORMALIZE AND VALIDATE SWITCHES
#----------------------------------------------------------
# Accepted enabled values: 1, true, .true.
# Accepted disabled values: 0, false, .false.
#
# Normalize each switch to 1 or 0 so the main driver can
# use consistent numeric comparisons.
#----------------------------------------------------------

foreach istage ( 1 2 3 4 5 6 7 )

    set switchname = run_stage_${istage}

    eval set switchvalue = \$$switchname

    if ( "$switchvalue" == "1" || \
         "$switchvalue" == "true" || \
         "$switchvalue" == ".true." ) then

        eval set $switchname = 1

    else if ( "$switchvalue" == "0" || \
              "$switchvalue" == "false" || \
              "$switchvalue" == ".false." ) then

        eval set $switchname = 0

    else

        echo "ERROR: Invalid value for ${switchname}: ${switchvalue}"
        echo "Accepted values: 1, 0, true, false, .true., .false."
        exit 1

    endif

end

echo "=================================================="
echo "WoFS stage configuration"
echo "  Stage 1 - Prior inflation       : ${run_stage_1}"
echo "  Stage 2 - Observations          : ${run_stage_2}"
echo "  Stage 3 - GSI analysis          : ${run_stage_3}"
echo "  Stage 4 - Diagnostics           : ${run_stage_4}"
echo "  Stage 5 - EnKF                  : ${run_stage_5}"
echo "  Stage 6 - Advance WRF members   : ${run_stage_6}"
echo "  Stage 7 - Finalize cycle        : ${run_stage_7}"
echo "=================================================="

#----------------------------------------------------------
# 1. INITIALIZE ENVIRONMENT
#----------------------------------------------------------

if ( ! $?SLURM_ARRAY_TASK_ID ) then
    setenv SLURM_ARRAY_TASK_ID 1
endif

source /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/module_list_intel_15_wps.csh
if ( $status != 0 ) then
    echo "ERROR: Failed to load module environment"
    exit 1
endif

setenv GSIRLT /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/WOFenv_rlt_2026

if ( ! -r "$GSIRLT" ) then
    echo "ERROR: Environment file not readable: $GSIRLT"
    exit 1
endif

source "$GSIRLT"
if ( $status != 0 ) then
    echo "ERROR: Failed to load WoFS environment"
    exit 1
endif

#----------------------------------------------------------
# 2. LOAD RUN CONFIGURATION
#----------------------------------------------------------

setenv ENVFILE "${TOP_DIR}/realtime.cfg.${event}"

if ( ! -r "$ENVFILE" ) then
    echo "ERROR: Configuration file not readable: $ENVFILE"
    exit 1
endif

source "$ENVFILE"
if ( $status != 0 ) then
    echo "ERROR: Failed to load run configuration"
    exit 1
endif

# Run-specific overrides.
setenv ENKFDIR1 /scratch4/NCEPDEV/stmp/Hongli.Wang/wofs_wrf/wrf/obs/WOFSRun20260727-133106d1
setenv ENKFDIR2 /scratch4/NCEPDEV/stmp/Hongli.Wang/wofs_wrf/wrf/resources/enkf

#----------------------------------------------------------
# 3. DEFINE RUN TIMES AND WORKING DIRECTORIES
#----------------------------------------------------------

set startdate = "${event}${cycle_start}00"
set datea     = "${startdate}"
set datef     = "202607270945"

if ( ! -x "${RUNDIR}/advance_time" ) then
    echo "ERROR: Missing advance_time: ${RUNDIR}/advance_time"
    exit 1
endif

cd "$RUNDIR"
if ( $status != 0 ) then
    echo "ERROR: Cannot enter RUNDIR: $RUNDIR"
    exit 1
endif

source "${SCRIPTDIR}/task_00_setup.csh"
if ( $status != 0 ) then
    echo "ERROR: task_00_setup.csh failed"
    exit 1
endif

#----------------------------------------------------------
# 4. COLD-START INITIALIZATION AND FIRST WRF FORECAST
#----------------------------------------------------------

if ( "${firstcycle_coldstart}" == ".true." && \
     "${firstcycle_coldstart_done}" == ".false." ) then

    echo "=================================================="
    echo "INITIALIZING COLD-START ENSEMBLE"
    echo "Initial time: ${startdate}"
    echo "=================================================="

    set datea     = "${startdate}"
    set thisstart = "${datea}"
    set thisend   = `echo "${thisstart} ${cycleinterval}m" | ${RUNDIR}/advance_time`

    if ( $status != 0 || "${thisend}" == "" ) then
        echo "ERROR: Cannot calculate initial forecast end time"
        exit 1
    endif

    set startyear  = `echo "${thisstart}" | cut -c1-4`
    set startmonth = `echo "${thisstart}" | cut -c5-6`
    set startday   = `echo "${thisstart}" | cut -c7-8`
    set starthour  = `echo "${thisstart}" | cut -c9-10`
    set startmin   = `echo "${thisstart}" | cut -c11-12`

    set endyear  = `echo "${thisend}" | cut -c1-4`
    set endmonth = `echo "${thisend}" | cut -c5-6`
    set endday   = `echo "${thisend}" | cut -c7-8`
    set endhour  = `echo "${thisend}" | cut -c9-10`
    set endmin   = `echo "${thisend}" | cut -c11-12`

    # Optional initialization task.
    source "${SCRIPTDIR}/task_01_initialize_coldstart.csh"
    if ( $status != 0 ) then
        echo "ERROR: /task_01_initialize_coldstart.csh"
        exit 1
    endif
    # Advance the initialized ensemble to the first analysis time.
    source "${SCRIPTDIR}/task_07_advance_members.csh"

    if ( $?task07_status ) then
        if ( $task07_status != 0 ) then
            echo "ERROR: Initial WRF ensemble advance failed"
            exit 1
        endif
    else
        echo "ERROR: task_07 did not return task07_status"
        exit 1
    endif

    # First assimilation time is the end of the initial forecast.
    set datea = "${thisend}"
    set firstcycle_coldstart_done = .true.
endif

# Preserve original initialization behavior.
# If you had ran coldstart previously, now set coldstart=.false. coldstart_done = .true.
if ( "${firstcycle_coldstart}" == ".false." && \
     "${firstcycle_coldstart_done}" == ".true." ) then

    set datea = `echo "${datea} ${cycleinterval}m" | ${RUNDIR}/advance_time`
    #get restart cycle time if you have ens forecst from a prevoius cycle
    #set datea = `echo "${datea} 45m" | ${RUNDIR}/advance_time`
    if ( $status != 0 || "${datea}" == "" ) then
        echo "ERROR: Cannot calculate initial analysis time"
        exit 1
    else
        echo "This cycle time: ${datea}"
    endif

    ##csh -fx "${SCRIPTDIR}/task_01_initialize.csh" "$datea"

    ##if ( $status != 0 ) then
    ##    echo "ERROR: task_01_initialize.csh failed"
    ##    exit 1
    ##endif

endif

#----------------------------------------------------------
# 5. MAIN DATA ASSIMILATION CYCLING LOOP
#----------------------------------------------------------

while ( 1 )

    if ( "${datea}" == "${datef}" ) then
        echo "Reached final analysis time: ${datea}"
        break
    endif

    echo "=================================================="
    echo "Starting WoFS assimilation cycle: ${datea}"
    echo "=================================================="

    # Define the analysis-to-forecast interval.
    set thisstart = "${datea}"
    set thisend = `echo "${thisstart} ${cycleinterval}m" | ${RUNDIR}/advance_time`

    if ( $status != 0 || "${thisend}" == "" ) then
        echo "ERROR: Cannot calculate cycle end time"
        exit 1
    endif

    # Extract time components.
    set startyear  = `echo "${thisstart}" | cut -c1-4`
    set startmonth = `echo "${thisstart}" | cut -c5-6`
    set startday   = `echo "${thisstart}" | cut -c7-8`
    set starthour  = `echo "${thisstart}" | cut -c9-10`
    set startmin   = `echo "${thisstart}" | cut -c11-12`

    set endyear  = `echo "${thisend}" | cut -c1-4`
    set endmonth = `echo "${thisend}" | cut -c5-6`
    set endday   = `echo "${thisend}" | cut -c7-8`
    set endhour  = `echo "${thisend}" | cut -c9-10`
    set endmin   = `echo "${thisend}" | cut -c11-12`

    # Reset observation switches for this cycle.
    set reflyes   = 1
    set vryes     = 0
    set cwpyes    = 1
    set okmesoyes = 0
    set goesyes   = 0
    set bufryes   = 0
    set aeriyes   = 0
    set dlyes     = 0
    set amvyes    = 0
    set fedyes    = 0
    set uasyes    = 0

    #------------------------------------------------------
    # STAGE 1: PRIOR INFLATION
    #------------------------------------------------------

    if ( ${run_stage_1} == 1 ) then

        echo "RUN STAGE 1: Prior inflation"

        csh "${SCRIPTDIR}/task_02_prior_inflation.csh" "${datea}"
        if ( $status != 0 ) then
            echo "ERROR: task_02_prior_inflation.csh failed"
            exit 1
        endif

    else
        echo "SKIP STAGE 1: Prior inflation"
    endif

    #------------------------------------------------------
    # STAGE 2: OBSERVATION PROCESSING
    #------------------------------------------------------

    if ( ${run_stage_2} == 1 ) then

        echo "RUN STAGE 2: Observation processing"

        csh "${SCRIPTDIR}/task_03_observations.csh" "${datea}"
        set task03_status = $status

        if ( ${task03_status} != 0 ) then
            echo "ERROR: task_03_observations.csh failed"
            exit 1
        endif

    else
        echo "SKIP STAGE 2: Observation processing"
    endif

    #------------------------------------------------------
    # STAGE 3: GSI ENSEMBLE ANALYSIS
    #------------------------------------------------------

    if ( ${run_stage_3} == 1 ) then

        echo "RUN STAGE 3: GSI ensemble analysis"

        csh "${SCRIPTDIR}/task_04_gsi.csh" "${datea}"
        set task04_status = $status

        if ( ${task04_status} != 0 ) then
            echo "ERROR: task_04_gsi.csh failed"
            exit 1
        endif

    else
        echo "SKIP STAGE 3: GSI ensemble analysis"
    endif

    #------------------------------------------------------
    # STAGE 4: ENSEMBLE-MEAN DIAGNOSTICS
    #------------------------------------------------------

    if ( ${run_stage_4} == 1 ) then

        echo "RUN STAGE 4: Ensemble-mean diagnostics"

        csh "${SCRIPTDIR}/task_05_diagnostics.csh" "${datea}"
        if ( $status != 0 ) then
            echo "ERROR: task_05_diagnostics.csh failed"
            exit 1
        endif

    else
        echo "SKIP STAGE 4: Ensemble-mean diagnostics"
    endif

    #------------------------------------------------------
    # STAGE 5: ENKF DATA ASSIMILATION
    #------------------------------------------------------

    if ( ${run_stage_5} == 1 ) then

        echo "RUN STAGE 5: EnKF data assimilation"

        #source "${SCRIPTDIR}/task_06_enkf.csh"
        csh "${SCRIPTDIR}/task_06_enkf.csh" "${datea}"
        if ( $status != 0 ) then
            echo "ERROR: task_06_enkf.csh failed"
            exit 1
        endif

        # Mark analysis as available only after EnKF succeeds.
        if ( ! -d "${FCST_DIR}" ) then
            echo "ERROR: FCST_DIR does not exist: ${FCST_DIR}"
            exit 1
        endif

        touch "${FCST_DIR}/analysis_${datea}_done"

        if ( $status != 0 ) then
            echo "ERROR: Cannot create analysis completion flag"
            exit 1
        endif

    else
        echo "SKIP STAGE 5: EnKF data assimilation"
        echo "WARNING: No new analysis completion flag will be created."
    endif

    #------------------------------------------------------
    # STAGE 6: ADVANCE WRF ENSEMBLE MEMBERS
    #------------------------------------------------------

    if ( ${run_stage_6} == 1 ) then

        # Do not advance beyond the requested final analysis time.
        if ( "${datea}" != "${datef}" ) then

            echo "RUN STAGE 6: Advance WRF ensemble members"

            source "${SCRIPTDIR}/task_07_advance_members.csh"

            if ( $?task07_status ) then
                if ( $task07_status != 0 ) then
                    echo "ERROR: task_07_advance_members.csh failed"
                    exit 1
                endif
            else
                echo "ERROR: task_07 did not return task07_status"
                exit 1
            endif

        else
            echo "SKIP STAGE 6: Already at final analysis time"
        endif

    else
        echo "SKIP STAGE 6: Advance WRF ensemble members"
    endif

    #------------------------------------------------------
    # STAGE 7: FINALIZE CYCLE
    #------------------------------------------------------

    if ( ${run_stage_7} == 1 ) then

        echo "RUN STAGE 7: Finalize cycle"

        source "${SCRIPTDIR}/task_08_finalize_cycle.csh"

        if ( $status != 0 ) then
            echo "ERROR: task_08_finalize_cycle.csh failed"
            exit 1
        endif

    else
        echo "SKIP STAGE 7: Finalize cycle"
    endif

    #------------------------------------------------------
    # STOP AT THE REQUESTED FINAL ANALYSIS TIME
    #------------------------------------------------------

    if ( "${datea}" == "${datef}" ) then
        echo "WoFS completed its requested cycling period at ${datea}"
        break
    endif

    # Advance to the next assimilation cycle.
    set datea = "${thisend}"

    echo "Next WoFS cycle: ${datea}"

end

echo "=================================================="
echo "WoFS driver finished."
echo "=================================================="

exit 0
