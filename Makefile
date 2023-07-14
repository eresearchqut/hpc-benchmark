SHELL=/bin/bash
architectures := amd_gpu amd_cpu intel_cpu nvidia_gpu
now := $(shell date +"%Y-%m-%d_%H-%M-%S")

applications:
	@for arch in ${architectures} ; do \
		appdir="applications/$$arch" ; \
		echo "Creating directory: $$appdir" ; \
		mkdir -p $$appdir ; \
	done

results:
	@for arch in ${architectures} ; do \
		resultsdir="results/$(now)/$$arch" ; \
		echo "Creating directory: $$resultsdir" ; \
		mkdir -p $$resultsdir ; \
	done


#########################
######## AMD GPU ########
#########################

amd_gpu_apps_dir := applications/amd_gpu
amd_gpu_results_dir := results/$(now)/amd_gpu

pull_amd_gpu_gromacs := $(amd_gpu_apps_dir)/gromacs.sif
pull_amd_gpu_hpl := $(amd_gpu_apps_dir)/hpl.sif
pull_amd_gpu_namd := $(amd_gpu_apps_dir)/namd.sif
pull_amd_gpu_openfoam := $(amd_gpu_apps_dir)/openfoam.sif
pull_amd_gpu_pytorch := $(amd_gpu_apps_dir)/pytorch.sif $(amd_gpu_apps_dir)/pytorch_uif.sif
pull_amd_gpu_tensorflow := $(amd_gpu_apps_dir)/tensorflow.sif $(amd_gpu_apps_dir)/tensorflow_uif.sif

pull_amd_gpu_deps := $(pull_amd_gpu_gromacs) $(pull_amd_gpu_hpl) $(pull_amd_gpu_namd) $(pull_amd_gpu_openfoam) $(pull_amd_gpu_pytorch) $(pull_amd_gpu_tensorflow)

pull_amd_gpu: $(pull_amd_gpu_gromacs) $(pull_amd_gpu_hpl) $(pull_amd_gpu_namd) $(pull_amd_gpu_openfoam) $(pull_amd_gpu_pytorch) $(pull_amd_gpu_tensorflow)

$(pull_amd_gpu_gromacs): applications
	apptainer pull applications/amd_gpu/gromacs.sif docker://amdih/gromacs:2022.3.amd1_174

$(pull_amd_gpu_hpl): applications
	apptainer pull applications/amd_gpu/hpl.sif docker://amdih/rochpl:6.0.amd0

run_amd_gpu_hpl_variations := \
	"mpirun_rochpl -P 1 -Q 1 -N 64000 --NB 512" \
	"mpirun_rochpl -P 1 -Q 2 -N 90112 --NB 512" \
	"mpirun_rochpl -P 2 -Q 2 -N 126976 --NB 512" \
	"mpirun_rochpl -P 2 -Q 4 -N 180224 --NB 512" \
	"mpirun_rochpl -P 1 -Q 1 -N 90112 --NB 512" \
	"mpirun_rochpl -P 2 -Q 1 -N 128000 --NB 512" \
	"mpirun_rochpl -P 2 -Q 2 -N 180224 --NB 512" \
	"mpirun_rochpl -P 2 -Q 4 -N 256000 --NB 512" \
	"mpirun_rochpl -P 4 -Q 4 -N 360448 --NB 512"

run_amd_gpu_hpl: $(pull_amd_gpu_hpl) results
	@index=0; \
	for variation in $(run_amd_gpu_hpl_variations); do \
		echo "HPL: $$variation" ; \
		result_dir=$(amd_gpu_results_dir)/hpl/$$index ; \
		mkdir -p $$result_dir ; \
		echo "$$variation" > $$result_dir/command ; \
		apptainer run --writable-tmpfs --pwd $$PWD/$$result_dir applications/amd_gpu/hpl.sif $$variation > $$result_dir/out ; \
		((index++)) ; \
	done

$(pull_amd_gpu_namd): applications
	apptainer pull applications/amd_gpu/namd.sif docker://amdih/namd:2.15a2-20211101

$(pull_amd_gpu_openfoam): applications
	apptainer pull applications/amd_gpu/openfoam.sif docker://amdih/openfoam:2206.1.amd3

$(pull_amd_gpu_pytorch): applications
	apptainer pull applications/amd_gpu/pytorch.sif docker://amdih/pytorch:rocm5.0_ubuntu18.04_py3.7_pytorch_1.10.0
	apptainer pull applications/amd_gpu/pytorch_uif.sif docker://amdih/uif-pytorch:uif1.1_rocm5.4.1_vai3.0_py3.7_pytorch1.12

$(pull_amd_gpu_tensorflow): applications
	apptainer pull applications/amd_gpu/tensorflow.sif docker://amdih/tensorflow:rocm5.0-tf2.7-dev
	apptainer pull applications/amd_gpu/tensorflow_uif.sif docker://amdih/uif-tensorflow:uif1.1_rocm5.4.1_vai3.0_tensorflow2.10

clean_results:
	rm -rf results/

clean: clean_results
	rm -rf applications/
