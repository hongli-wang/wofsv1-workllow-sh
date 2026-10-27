
#!/bin/csh
# task_03_observations.csh
#
# Usage:
#   ./task_03_observations.csh YYYYMMDDHHMM
#
# Generates gsiparm.anl and prepares the observation inputs.
# Original observation flags and file naming conventions are retained.

if ( $#argv < 1 ) then
    echo "Usage: task_03_observations.csh YYYYMMDDHHMM"
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

# ----------------------------------------------------------------------
# Observation flags from the original driver
# ----------------------------------------------------------------------
set reflyes = 1
set vryes = 0
set cwpyes = 1
set okmesoyes = 0
set goesyes = 0
set bufryes = 0
set aeriyes = 0
set dlyes = 0
set amvyes = 0
set fedyes = 0
set uasyes = 0

set startyear  = `echo ${thisstart} | cut -c1-4`
set startmonth = `echo ${thisstart} | cut -c5-6`
set startday   = `echo ${thisstart} | cut -c7-8`
set starthour  = `echo ${thisstart} | cut -c9-10`
set startmin   = `echo ${thisstart} | cut -c11-12`

set yyyymmdd = `echo ${thisstart} | cut -c1-8`
set hhmm = `echo ${thisstart} | cut -c9-12`
set timestr = ${hhmm}
set fulltime = ${thisstart}

set obsdir1 = ${ENKFDIR1}/${event}${timestr}
set obsdir2 = ${ENKFDIR1}/${fulltime}

# ----------------------------------------------------------------------
# Wait for observations, preserving the original waitinterval
# ----------------------------------------------------------------------
set datew = `echo ${datea} ${waitinterval}m | ${RUNDIR}/advance_time`
set today = `date -u +%Y%m%d%H%M`

while ( "${today}" < "${datew}" )
    echo "WAITING FOR OBSERVATIONS ${datea} ${datew} ${today}"
    sleep 10
    set today = `date -u +%Y%m%d%H%M`
end

# ----------------------------------------------------------------------
# DBZ observations
# ----------------------------------------------------------------------
if ( -e "${obsdir1}/${timestr}-dbzobs.nc" ) then
    /bin/cp -pv "${obsdir1}/${timestr}-dbzobs.nc" "${ENKFDIR}/dbzobs.nc"
else if ( -e "${obsdir2}/${fulltime}-dbzobs.nc" ) then
    /bin/cp -pv "${obsdir2}/${fulltime}-dbzobs.nc" "${ENKFDIR}/dbzobs.nc"
else
    echo "WARNING: DBZ file not found for ${timestr}"
endif

# The original driver enables the DBZ observation flag and additive-noise
# setup even when the observation file is not found. Preserve that behavior.
set reflyes = 1

# ----------------------------------------------------------------------
# Additive-noise grid-reflectivity job
# ----------------------------------------------------------------------
if ( -e "${ADDNOISEDIR}/grid_refl_obs_gsi.exe" ) then
    /bin/cp -p "${ADDNOISEDIR}/grid_refl_obs_gsi.exe" "${ENKFDIR}/"
else
    echo "WARNING: grid_refl_obs_gsi.exe not found"
endif

if ( -e "${SCRIPTDIR}/run_grid_refl.job" ) then
    /bin/cp -p "${SCRIPTDIR}/run_grid_refl.job" "${ENKFDIR}/"
else
    echo "WARNING: run_grid_refl.job not found"
endif

if ( -e "${ENKFDIR}/grid_refl_obs_gsi.exe" && -e "${ENKFDIR}/run_grid_refl.job" ) then

    # Remove a stale completion flag before the next submission.
    if ( -e "${ENKFDIR}/refl_done" ) then
        /bin/rm -f "${ENKFDIR}/refl_done"
    endif

    cd "${ENKFDIR}"
    sbatch run_grid_refl.job
    if ( $status != 0 ) then
        echo "ERROR: Could not submit run_grid_refl.job"
        exit 1
    endif

    while ( ! -e "${ENKFDIR}/refl_done" )
        echo "WAITING FOR NCL REFL TO FINISH"
        sleep 2
    end
else
    echo "WARNING: Grid-reflectivity executable or job script missing"
    echo "WARNING: ADDITIVE NOISE NOT APPLIED"
endif

# ----------------------------------------------------------------------
# Optional observations
#
# These retain the original disabled settings. Enable the relevant
# sections here when those observation sources are ready.
# ----------------------------------------------------------------------
# Radial velocity:
# set vryes = 0
# SEARCH FOR RADIAL VELOCITY OBSERVATIONS
##if ( -e ${VEL_DIR}/${yyyymmdd}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ) then
##   /bin/cp -pv ${VEL_DIR}/${yyyymmdd}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/vrobs.nc
#if ( -e ${LRAD_DIR}/VEL/${event}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ) then
#   /bin/cp -pv ${LRAD_DIR}/VEL/${event}/obs_seq_VR_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/vrobs.nc
#   set vryes = 1
#endif
#
# CWP:
#set cwpyes = 0
# SEARCH FOR NEW CWP OBSERVATION FILES
#if ( -e ${SAT_DIR}/CWP/${startyear}/${thisstart}_GOES${GOESV}_CWP_OBS.nc ) then
#   /bin/cp -pv  ${SAT_DIR}/CWP/${startyear}/${thisstart}_GOES${GOESV}_CWP_OBS.nc ${ENKFDIR}/cwpobs.nc
#   set cwpyes = 1
#endif
if ( -e "${obsdir1}/${timestr}-cwpobs.nc" ) then
    /bin/cp -pv "${obsdir1}/${timestr}-cwpobs.nc" "${ENKFDIR}/cwpobs.nc"
set cwpyes = 1
#else if ( -e "${obsdir2}/${fulltime}-cwpobs.nc" ) then
#    /bin/cp -pv "${obsdir2}/${fulltime}-cwpobs.nc" "${ENKFDIR}/cwpobs.nc"
else
    echo "WARNING: CWP file not found for ${timestr}"
endif

#
# GOES radiances:
#set goesyes = 0
   # AMVs DATA from GOES-16   ----  Swapan Mallick
   # SEARCH FOR AMVs FILES
   #if ( -e ${SAT_DIR}/AMV/${startyear}/${thisstart}_GOES${GOESV}AMV.nc ) then
       #/bin/cp -pv ${SAT_DIR}/AMV/${startyear}/${thisstart}_GOES${GOESV}AMV.nc ${ENKFDIR}/goes_amv.nc
       #set amvyes = 1
   #endif

   # SEARCH FOR GOES-16 RADIANCE FILES
   #if ( -e ${SAT_DIR}/RADIANCE/${startyear}/D2/${thisstart}_GOES${GOESV}_TB_ALLSKY.nc ) then
   #   /bin/cp -pv ${SAT_DIR}/RADIANCE/${startyear}/D2/${thisstart}_GOES${GOESV}_TB_ALLSKY.nc ${ENKFDIR}/goes.nc
   #   set goesyes = 1
   #endif
#
# Mesonet:
# set okmesoyes = 0
   # COPY AVAILBLE MESONET AND PREBUFR OBS TO WORKING DIR
   #if ( -e ${OBSDIR}/Mesonet/${startyear}/${startmonth}/${startday}/mesonet.realtime.${thisstart}.mdf ) then
   #   /bin/cp -pv ${OBSDIR}/Mesonet/${startyear}/${startmonth}/${startday}/mesonet.realtime.${thisstart}.mdf ${ENKFDIR}/okmeso.mdf
   #   set okmesoyes = 1
   #endif
#
# Conventional BUFR:
# set bufryes = 0
   # BUFR DATA
   # if ( ${startmin} == 15 ) then
   #    if ( -e ${OBSDIR}/EBUFR/${startyear}/${startmonth}/${startday}/rap.${startyear}${startmonth}${startday}${starthour}.prepbufr.tm00 ) then
   #       set pbufrfile = ${OBSDIR}/EBUFR/${startyear}/${startmonth}/${startday}/rap.${startyear}${startmonth}${startday}${starthour}.prepbufr.tm00
   #       /bin/cp -pv ${pbufrfile} ${ENKFDIR}/prepbufr
   #       set  bufryes = 1
   #       echo "BUFR DATA ASSIMILATED"
   #    else if ( -e ${OBSDIR}/RBUFR/${startyear}/${startmonth}/${startday}/rtma.${startyear}${startmonth}${startday}${starthour}00.prepbufr.tm00 ) then
   #       set pbufrfile = ${OBSDIR}/RBUFR/${startyear}/${startmonth}/${startday}/rtma.${startyear}${startmonth}${startday}${starthour}00.prepbufr.tm00
   #       /bin/cp -pv ${pbufrfile} ${ENKFDIR}/prepbufr
   #       set  bufryes = 1
   #       echo "BUFR DATA ASSIMILATED"
   #    endif
   # endif
#
# AERI / DWL / AMV / FED / UAS:
# set aeriyes = 0
# set dlyes = 0
    #set dlbufrfile = ${SGP_DIR}/DLBUFR/dl_${thisstart}.dlbufr
    #if ( -e ${dlbufrfile} ) then
            #     /bin/cp -pv ${dlbufrfile} ${ENKFDIR}/dlbufr
            #set  dlyes = 1
            #echo "DWL BUFR DATA ASSIMILATED"
    #endif

    #set aeribufrfile = ${SGP_DIR}/AERIBUFR/aeri_${thisstart}.aeribufr
    #if ( -e ${aeribufrfile} ) then
            #     /bin/cp -pv ${aeribufrfile} ${ENKFDIR}/aeribufr
            #set  aeriyes = 1
            #echo "AERI BUFR DATA ASSIMILATED"
    #endif
# set amvyes = 0
# set fedyes = 0
    #fed OBS from GLM G16 ! added by YPW
    #set fedfile = ${FED_DIR}/obs_seq_GLM_G16_${startyear}${startmonth}${startday}_${starthour}${startmin}.nc
    #if (-e ${fedfile})then
    #    /bin/cp -pv ${fedfile} ${ENKFDIR}/fedobs.nc
    #    set fedyes = 1
    #    echo "FED BUFR DATA ASSIMILATED"
    #endif
# set uasyes = 0
    # UAS observations
    #if ( -e ${UAS_DIR}/${yyyymmdd}_50_100_weight/obs_seq_${yyyymmdd}_${hhmm}.nc) then
    #    /bin/cp -pv ${UAS_DIR}/${yyyymmdd}_50_100_weight/obs_seq_${yyyymmdd}_${hhmm}.nc ${ENKFDIR}/uasobs.nc
    #     set uasyes = 1  # for CTRL run
    #     echo "UAS DATA ASSIMILATED"
    #endif

echo "Observation flags:"
echo "${reflyes} ${vryes} ${cwpyes} ${bufryes} ${okmesoyes} ${goesyes} ${dlyes} ${aeriyes} ${fedyes} ${uasyes}"

# ----------------------------------------------------------------------
# Generate the observation section of gsiparm.anl
# ----------------------------------------------------------------------
# DBZ: Temporary change to 1.04 to avoid all data out of time window for the Oct 10 2026 retro case with data from Azure.

if ( -e "${ENKFDIR}/gsiparm.anl.obs" ) then
    /bin/rm -f "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${bufryes} == 1 ) then
    echo "   prepbufr         ps          null        ps        1.0      0       0           0.35" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "   prepbufr         t           null        t         1.0      0       0           0.35" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "   prepbufr         td          null        td        1.0      0       0           0.35" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "   prepbufr         uv          null        uv        1.0      0       0           0.35" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${okmesoyes} == 1 ) then
    echo "    okmeso.mdf      okt          null        okt       1.0      0       0         0.125" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "    okmeso.mdf      oktd         null        oktd      1.0      0       0         0.125" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "    okmeso.mdf      okuv         null        okuv      1.0      0       0         0.125" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "    okmeso.mdf      okps         null        okps      1.0      0       0         0.125" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${aeriyes} == 1 ) then
    echo "    aeribufr        aerit        null        aerit     1.0      0       0         0.25" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "    aeribufr        aeritd       null        aeritd    1.0      0       0         0.25" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${dlyes} == 1 ) then
    echo "    dlbufr          dlw          null        dlw       1.0      0       0         0.25" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${reflyes} == 1 ) then
    echo "    dbzobs.nc       dbz          null        dbz       1.0      0       0         1.04166666667" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${vryes} == 1 ) then
    echo "    vrobs.nc        rw           null        rw        1.0      0       0         0.11666666667" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${cwpyes} == 1 ) then
    echo "    cwpobs.nc       cwp          null        cwp       1.0      0       0         0.175" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${goesyes} == 1 ) then
    echo "    goes.nc         abi          g16         abi_g16   0.0      0       0         0.125" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${amvyes} == 1 ) then
    echo "    goes_amv.nc     uv           null        uv        1.0      0       0         0.35" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${fedyes} == 1 ) then
    echo "    fedobs.nc       fed          null        fed       1.0      0       0         0.08333333334" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

if ( ${uasyes} == 1 ) then
    echo "    uasobs.nc       uast         null        uast      1.0      0       0         0.25" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "    uasobs.nc       uastd        null        uastd     1.0      0       0         0.25" >> "${ENKFDIR}/gsiparm.anl.obs"
    echo "    uasobs.nc       uasuv        null        uasuv     1.0      0       0         0.25" >> "${ENKFDIR}/gsiparm.anl.obs"
endif

# ----------------------------------------------------------------------
# Generate the GSI grid/vertical namelist and final gsiparm.anl
# ----------------------------------------------------------------------
set advsed = "${ENKFDIR}/advModel.sed"
set gsihead = "${ENKFDIR}/gsiparm.anl.head"

cat >! "${advsed}" << EOF
/NLAT=xxx,NLON=yyy,nsig=zzz,/c\\
JCAP=62,JCAP_B=62,NLAT=${NLATS},NLON=${NLONS},nsig=${NLEVS},
EOF

sed -f "${advsed}" "${TEMPLATE_DIR}/gsiparm.anl.template.head" >! "${gsihead}"
if ( $status != 0 ) then
    echo "ERROR: Could not generate gsiparm.anl.head"
    exit 1
endif

cat "${gsihead}" "${ENKFDIR}/gsiparm.anl.obs" "${TEMPLATE_DIR}/gsiparm.anl.template.tail" >! "${ENKFDIR}/gsiparm.anl"
if ( $status != 0 ) then
    echo "ERROR: Could not generate gsiparm.anl"
    exit 1
endif

/bin/rm -f "${advsed}" "${gsihead}"

echo "Observation setup completed for ${datea}"
exit 0

