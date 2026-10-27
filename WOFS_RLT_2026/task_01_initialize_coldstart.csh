#!/bin/csh
#
# task_01_initialize.csh
# Initialize the WoFS EnKF working directory.
#
# Usage:
#   ./task_01_initialize.csh YYYYMMDDHHMM
#

#if ( $#argv < 1 ) then
#    echo "Usage: task_01_initialize.csh YYYYMMDDHHMM"
#    exit 1
#endif

#set datea = "$argv[1]"
set startdate = "${event}${cycle_start}00"

source /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/module_list_intel_15_wps.csh

set GSIRLT = /scratch4/NCEPDEV/fv3-cam/Hongli.Wang/WoFS/scripts/WOFenv_rlt_2026
source ${GSIRLT}

set ENVFILE = ${TOP_DIR}/realtime.cfg.${event}
source ${ENVFILE}

if ( ! -d "${RUNDIR}" ) then
    echo "ERROR: RUNDIR does not exist: ${RUNDIR}"
    exit 1
endif

mkdir -p "${RESULTSDIR}/stdout" "${ENKFDIR}"
if ( $status != 0 ) then
    echo "ERROR: Could not create required working directories"
    exit 1
endif

if ( ! -d "${TEMPLATE_DIR}" ) then
    echo "ERROR: TEMPLATE_DIR does not exist: ${TEMPLATE_DIR}"
    exit 1
endif

if ( ! -e "${RUNDIR}/input.nml" ) then
    echo "ERROR: Missing ${RUNDIR}/input.nml"
    exit 1
endif

# Copy the fixed EnKF input files.
foreach src ( "${SATANGL}" "${SATINFO}" "${CONVINFO}" "${OZINFO}" "${SATBIASING}" "${SATBIASPC}" "${TEMPLATE_DIR}/obs_locinfo_multi" "${RUNDIR}/input.nml" )
    if ( ! -e "${src}" ) then
        echo "ERROR: Required initialization file missing: ${src}"
        exit 1
    endif
end

/bin/cp -p "${SATANGL}"     "${ENKFDIR}/satbias_angle"
/bin/cp -p "${SATINFO}"     "${ENKFDIR}/satinfo"
/bin/cp -p "${CONVINFO}"    "${ENKFDIR}/convinfo"
/bin/cp -p "${OZINFO}"      "${ENKFDIR}/ozinfo"
/bin/cp -p "${SATBIASING}"  "${ENKFDIR}/satbias_in"
/bin/cp -p "${SATBIASPC}"   "${ENKFDIR}/satbias_pc"
/bin/cp -p "${TEMPLATE_DIR}/obs_locinfo_multi" "${ENKFDIR}/obs_locinfo"
/bin/cp -p "${RUNDIR}/input.nml" "${ENKFDIR}/input.nml"

if ( $status != 0 ) then
    echo "ERROR: Failed copying fixed EnKF input files"
    exit 1
endif

# Copy ensemble backgrounds. Do not delete existing member data here.
mkdir -p ${RUNDIR}/${startdate}
set imem = 1
while ( ${imem} <= ${ENS_SIZE} )
    set icfile = "${RUNDIR}/ic${imem}/wrfinput_d01_ic"
    if ( ! -e "${icfile}" ) then
        echo "ERROR: Missing initial condition: ${icfile}"
        exit 1
    endif

    #/bin/cp -p "${icfile}" "${ENKFDIR}/wrfinput_d01.${imem}"
    /bin/cp -p "${icfile}" "${RUNDIR}/${startdate}/wrfinput_d01.${imem}"
    if ( $status != 0 ) then
        echo "ERROR: Failed to copy initial condition for member ${imem}"
        exit 1
    endif

    @ imem++
end

# Prepare the boundary-condition links when source files exist.
set imem = 1
while ( ${imem} <= ${ENS_SIZE} )
    set bdyfile = "${RUNDIR}/mem${imem}/wrfbdy_d01.${imem}"

    if ( -e "${bdyfile}" ) then
        /bin/cp -p "${bdyfile}"  "${RUNDIR}/${startdate}/wrfbdy_d01.${imem}"
        # No subhourly BDY files. All forecasts share the BDY files here. ???
        /bin/ln -sf "${bdyfile}" "${ENKFDIR}/wrfbdy_d01.${imem}"
    else
        echo "WARNING: Boundary condition not found: ${bdyfile}"
    endif

    @ imem++
end

echo "Initialization completed for ${datea}"
exit 0

