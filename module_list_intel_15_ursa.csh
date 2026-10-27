# Initialize the module command.
if ( -r /etc/profile.d/modules.csh ) then
    source /etc/profile.d/modules.csh
else if ( -r /usr/share/Modules/init/csh ) then
    source /usr/share/Modules/init/csh
else
    echo "ERROR: Cannot locate C-shell module initialization"
    exit 1
endif
# Clean previous modules
module purge

# Core tools
module load cmake/3.30.2

# Intel compilers
module load intel-oneapi-compilers/2023.2.0

# Intel MPI (compatible with the compiler)
module load intel-oneapi-mpi/2021.13.1

# Parallel NetCDF (optional but recommended for MPI I/O)
module load parallel-netcdf/1.12.3

# HDF5 and NetCDF
module load hdf5/1.14.3
module load netcdf-c/4.9.2
module load netcdf-fortran/4.6.1

module load libtirpc/1.3.3

module load jasper/2.0.32

setenv NETCDF /scratch3/NAGAPE/wof/netcdf
setenv NETCDF_FORTRAN $NETCDF
setenv PATH $NETCDF/bin:$PATH
setenv LD_LIBRARY_PATH $NETCDF/lib:$LD_LIBRARY_PATH
setenv LIBRARY_PATH $NETCDF/lib:$LIBRARY_PATH
setenv CPATH $NETCDF/include:$CPATH

setenv LIBTIRPC_DIR $LIBTIRPC_ROOT
setenv LIBTIRPC_INC $LIBTIRPC_DIR/include/tirpc
setenv LIBTIRPC_LIB $LIBTIRPC_DIR/lib


setenv JASPERLIB /apps/spack-2024-12/linux-rocky9-x86_64/gcc-11.4.1/jasper-2.0.32-ti3pzbhcmtzczjmisaaqn724zvjdm4td/lib64

setenv JASPERINC /apps/spack-2024-12/linux-rocky9-x86_64/gcc-11.4.1/jasper-2.0.32-ti3pzbhcmtzczjmisaaqn724zvjdm4td/include
