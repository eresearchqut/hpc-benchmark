.PHONY: clean
SHELL=/bin/bash
architectures := amd_gpu amd_cpu intel_cpu nvidia_gpu
now := $(shell date +"%Y-%m-%d_%H-%M-%S")

application_dirs := applications/amd_gpu applications/amd_cpu applications/intel_cpu applications/nvidia_gpu

#applications: $(application_dirs)
applications:
	@for arch in ${architectures} ; do \
		appdir="applications/$$arch" ; \
		echo "Creating directory: $$appdir" ; \
		mkdir -p $$appdir ; \
	done

data:
	mkdir -p data/gromacs/adh_dodec data/gromacs/cellulose_nve data/gromacs/stmv

	wget https://github.com/amd/InfinityHub-CI/raw/569d827145ee674774d2738ec30e79374bc48a03/gromacs/docker/benchmark/adh_dodec/adh_dodec.tar.gz -O data/gromacs/adh_dodec.tar.gz
	tar xvf data/gromacs/adh_dodec.tar.gz -C data/gromacs/adh_dodec
	rm data/gromacs/adh_dodec.tar.gz

	wget https://github.com/amd/InfinityHub-CI/raw/569d827145ee674774d2738ec30e79374bc48a03/gromacs/docker/benchmark/cellulose_nve/cellulose_nve.tar.gz -O data/gromacs/cellulose_nve.tar.gz
	tar xvf data/gromacs/cellulose_nve.tar.gz -C data/gromacs/cellulose_nve
	rm data/gromacs/cellulose_nve.tar.gz

	wget https://github.com/amd/InfinityHub-CI/raw/569d827145ee674774d2738ec30e79374bc48a03/gromacs/docker/benchmark/stmv/stmv.tar.gz -O data/gromacs/stmv.tar.gz
	tar xvf data/gromacs/stmv.tar.gz -C data/gromacs/stmv
	rm data/gromacs/stmv.tar.gz



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
run_amd_gpu: $(run_amd_gpu_gromacs) $(run_amd_gpu_hpl)

$(pull_amd_gpu_gromacs): applications
	apptainer pull applications/amd_gpu/gromacs.sif docker://amdih/gromacs:2022.3.amd1_174

run_amd_gpu_gromacs_variations := \
	"-pin on -nsteps 100000 -resetstep 90000 -ntmpi 1 -ntomp 64 -noconfout -nb gpu -bonded cpu -pme gpu -v -nstlist 100 -gpu_id 0 -s topol.tpr" \
	"-pin on -nsteps 100000 -resetstep 90000 -ntmpi 2 -ntomp 32 -noconfout -nb gpu -bonded gpu -pme gpu -npme 1 -v -nstlist 200 -gpu_id 01 -s topol.tpr" \
	"-pin on -nsteps 100000 -resetstep 90000 -ntmpi 3 -ntomp 24 -noconfout -nb gpu -bonded gpu -pme gpu -npme 1 -v -nstlist 300 -gpu_id 012 -s topol.tpr"

run_amd_gpu_gromacs: $(pull_amd_gpu_gromacs) results
	@for problem in adh_dodec cellulose_nve stmv; do \
		index=0; \
		for variation in $(run_amd_gpu_gromacs_variations); do \
			result_dir=$$PWD/$(amd_gpu_results_dir)/gromacs/$$problem/$$index; \
			mkdir -p $$result_dir; \
			echo "$$problem: $$result_dir"; \
			echo "$$variation" > $$result_dir/command; \
			ln -s $$PWD/data/gromacs/$$problem/topol.tpr $$result_dir/topol.tpr; \
			apptainer run --pwd $$result_dir applications/amd_gpu/gromacs.sif gmx mdrun $$variation |& tee $$result_dir/out; \
			((index++)); \
		done \
	done

$(pull_amd_gpu_hpl): applications
	apptainer pull applications/amd_gpu/hpl.sif docker://amdih/rochpl:6.0.amd0

run_amd_gpu_hpl_variations := \
	"-P 1 -Q 1 -N 64000 --NB 512" \
	"-P 1 -Q 2 -N 90112 --NB 512" \
	"-P 2 -Q 2 -N 126976 --NB 512" \
	"-P 2 -Q 4 -N 180224 --NB 512" \
	"-P 1 -Q 1 -N 90112 --NB 512" \
	"-P 2 -Q 1 -N 128000 --NB 512" \
	"-P 2 -Q 2 -N 180224 --NB 512" \
	"-P 2 -Q 4 -N 256000 --NB 512" \
	"-P 4 -Q 4 -N 360448 --NB 512"

run_amd_gpu_hpl: $(pull_amd_gpu_hpl) results
	@index=0; \
	for variation in $(run_amd_gpu_hpl_variations); do \
		echo "HPL: $$variation"; \
		result_dir=$(amd_gpu_results_dir)/hpl/$$index; \
		mkdir -p $$result_dir; \
		echo "$$variation" > $$result_dir/command; \
		apptainer run --writable-tmpfs --pwd $$PWD/$$result_dir applications/amd_gpu/hpl.sif mpirun_rochpl $$variation |& tee $$result_dir/out; \
		((index++)); \
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


########################
###### NVIDIA GPU ######
########################

nvidia_gpu_apps_dir := applications/nvidia_gpu
nvidia_gpu_results_dir := results/$(now)/nvidia_gpu

pull_nvidia_gpu_ngc := $(nvidia_gpu_apps_dir)/ngc/ngc-cli/ngc
pull_nvidia_gpu_ngc_config := $(HOME)/.ngc/config
pull_nvidia_gpu_docker_config := $(HOME)/.docker/config.json

pull_nvidia_gpu_gromacs := $(nvidia_gpu_apps_dir)/gromacs.sif
pull_nvidia_gpu_hpl := $(nvidia_gpu_apps_dir)/hpl.sif
pull_nvidia_gpu_namd := $(nvidia_gpu_apps_dir)/namd.sif
pull_nvidia_gpu_openfoam := $(nvidia_gpu_apps_dir)/openfoam.sif
pull_nvidia_gpu_pytorch := $(nvidia_gpu_apps_dir)/pytorch.sif $(nvidia_gpu_apps_dir)/pytorch_uif.sif
pull_nvidia_gpu_tensorflow := $(nvidia_gpu_apps_dir)/tensorflow.sif $(nvidia_gpu_apps_dir)/tensorflow_uif.sif

pull_nvidia_gpu_deps := $(pull_nvidia_gpu_gromacs) $(pull_nvidia_gpu_hpl) $(pull_nvidia_gpu_namd) $(pull_nvidia_gpu_openfoam) $(pull_nvidia_gpu_pytorch) $(pull_nvidia_gpu_tensorflow)

pull_nvidia_gpu: $(pull_nvidia_gpu_ngc_config) $(pull_nvidia_gpu_docker_config)
#pull_nvidia_gpu: $(pull_nvidia_gpu_gromacs) $(pull_nvidia_gpu_hpl) $(pull_nvidia_gpu_namd) $(pull_nvidia_gpu_openfoam) $(pull_nvidia_gpu_pytorch) $(pull_nvidia_gpu_tensorflow)
#run_nvidia_gpu: $(run_nvidia_gpu_gromacs) $(run_nvidia_gpu_hpl)

$(pull_nvidia_gpu_ngc):
	mkdir -p applications/nvidia_gpu/
	wget --content-disposition https://ngc.nvidia.com/downloads/ngccli_linux.zip -O applications/nvidia_gpu/ngc.zip
	unzip -o applications/nvidia_gpu/ngc.zip -d applications/nvidia_gpu/ngc
	chmod u+x applications/nvidia_gpu/ngc/ngc-cli/ngc

$(pull_nvidia_gpu_ngc_config): $(pull_nvidia_gpu_ngc)
	@echo "Login to NVIDIA NGC, and follow the instructions here to enter your API key"
	@echo "https://ngc.nvidia.com/setup/api-key"
	./applications/nvidia_gpu/ngc/ngc-cli/ngc config set

$(pull_nvidia_gpu_docker_config): $(pull_nvidia_gpu_ngc_config)
	@echo "Login to NVIDIA NGC, and follow the instructions here to enter your API key"
	@echo "https://ngc.nvidia.com/setup/api-key"
	docker login nvcr.io

$(pull_nvidia_gpu_gromacs): $(pull_nvidia_gpu_docker_config)
	apptainer pull applications/nvidia_gpu/gromacs.sif docker://nvcr.io/hpc/gromacs:2022.3

run_nvidia_gpu_gromacs_variations := \
	"-pin on -nsteps 100000 -resetstep 90000 -ntmpi 1 -ntomp 64 -noconfout -nb gpu -bonded cpu -pme gpu -v -nstlist 100 -gpu_id 0 -s topol.tpr" \
	"-pin on -nsteps 100000 -resetstep 90000 -ntmpi 2 -ntomp 32 -noconfout -nb gpu -bonded gpu -pme gpu -npme 1 -v -nstlist 200 -gpu_id 01 -s topol.tpr" \
	"-pin on -nsteps 100000 -resetstep 90000 -ntmpi 3 -ntomp 24 -noconfout -nb gpu -bonded gpu -pme gpu -npme 1 -v -nstlist 300 -gpu_id 012 -s topol.tpr"

run_nvidia_gpu_gromacs: $(pull_nvidia_gpu_gromacs) results
	@for problem in adh_dodec cellulose_nve stmv; do \
		index=0; \
		for variation in $(run_nvidia_gpu_gromacs_variations); do \
			result_dir=$$PWD/$(nvidia_gpu_results_dir)/gromacs/$$problem/$$index; \
			mkdir -p $$result_dir; \
			echo "$$problem: $$result_dir"; \
			echo "$$variation" > $$result_dir/command; \
			ln -s $$PWD/data/gromacs/$$problem/topol.tpr $$result_dir/topol.tpr; \
			apptainer run --nv --pwd $$result_dir applications/nvidia_gpu/gromacs.sif gmx mdrun $$variation |& tee $$result_dir/out; \
			((index++)); \
		done \
	done

$(pull_nvidia_gpu_hpl): $(pull_nvidia_gpu_docker_config)
	apptainer pull applications/nvidia_gpu/hpl.sif docker://nvcr.io/nvidia/hpc-benchmarks:23.5

run_nvidia_gpu_hpl_variations := \
	"-P 1 -Q 1 -N 64000 --NB 512" \
	"-P 1 -Q 2 -N 90112 --NB 512" \
	"-P 2 -Q 2 -N 126976 --NB 512" \
	"-P 2 -Q 4 -N 180224 --NB 512" \
	"-P 1 -Q 1 -N 90112 --NB 512" \
	"-P 2 -Q 1 -N 128000 --NB 512" \
	"-P 2 -Q 2 -N 180224 --NB 512" \
	"-P 2 -Q 4 -N 256000 --NB 512" \
	"-P 4 -Q 4 -N 360448 --NB 512"

run_nvidia_gpu_hpl: $(pull_nvidia_gpu_hpl) results
	@index=0; \
	for variation in $(run_nvidia_gpu_hpl_variations); do \
		echo "HPL: $$variation"; \
		result_dir=$(nvidia_gpu_results_dir)/hpl/$$index; \
		mkdir -p $$result_dir; \
		echo "$$variation" > $$result_dir/command; \
		apptainer run --nv --writable-tmpfs --pwd $$PWD/$$result_dir applications/nvidia_gpu/hpl.sif hpcg.sh $$variation |& tee $$result_dir/out; \
		((index++)); \
	done

clean_applications:
	rm -rf applications/

clean_results:
	rm -rf results/

clean_data:
	rm -rf data/

clean: clean_applications clean_results clean_data
