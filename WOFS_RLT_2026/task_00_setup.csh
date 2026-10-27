
#!/bin/csh -f
#
# task_00_setup.csh
# Create and validate working directories.
# This file is sourced by the main driver.
#

echo "Setting up WoFS working directories"

if ( ! -d "${RESULTSDIR}" ) then
    mkdir -p "${RESULTSDIR}"
    if ( $status != 0 ) then
        echo "ERROR: Cannot create ${RESULTSDIR}"
        exit 1
    endif
endif

if ( ! -d "${RESULTSDIR}/stdout" ) then
    mkdir -p "${RESULTSDIR}/stdout"
endif

if ( ! -d "${ENKFDIR}" ) then
    mkdir -p "${ENKFDIR}"
endif

if ( ! -d "${FCST_DIR}" ) then
    mkdir -p "${FCST_DIR}"
endif

if ( ! -d "${RUNDIR}" ) then
    echo "ERROR: Run directory missing: ${RUNDIR}"
    exit 1
endif

echo "WoFS directory setup completed"

