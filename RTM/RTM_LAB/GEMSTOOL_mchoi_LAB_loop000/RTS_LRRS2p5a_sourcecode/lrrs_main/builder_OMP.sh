rm *.o *.mod 
exit

gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_pars.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_inputs_def.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_outputs_def.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_sup_brdf_def.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_sup_sleave_def.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_sup_ss_def.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_sup_def.f90
gfortran -c  -fopenmp -frecursive ../lrrs_def/lrrs_io_defs.f90

gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_geometry.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_aux2.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_Taylor.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_io_check.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_deltamscaling.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_raman_spectroscopy.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_generate_ramanops.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_writemodules.f90

gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_postprocessing_1.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_miscsetups_1.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_rtsolutions_1.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_corrections_1.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_bvproblem.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_converge.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_raman_intensity_1.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_elastic_intensity_1.f90

gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_rrsoptical_master.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_sources_master_1.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_elastic_master_1_REENG.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_fourier_master_1_REENG.f90
gfortran -c  -fopenmp -frecursive ../lrrs_main/lrrs_main_master_REENG.f90


