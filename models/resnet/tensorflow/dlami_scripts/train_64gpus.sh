# Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Ensure you have Horovod, OpenMPI, and Tensorflow installed on each machine
# Specify hosts in the file `hosts`

# Below was tested on DLAMI v15 Ubuntu. 
# If you are using AmazonLinux change ens3 in line 15 to eth0
# If you have version 12 or older, you need to remove line 15 below.
source activate tensorflow_p36
cd ..

# adjust the learning rate based on how many gpus are being used. 
# for x gpus use x*0.1 as the learning rate for resnet50 with 256batch size per gpu
/home/ubuntu/anaconda3/envs/tensorflow_p36/bin/mpirun -np 64 -hostfile hosts -mca plm_rsh_no_tree_spawn 1 \
	-bind-to socket -map-by slot \
	-x HOROVOD_HIERARCHICAL_ALLREDUCE=1 -x HOROVOD_FUSION_THRESHOLD=16777216 \
	-x NCCL_MIN_NRINGS=4 -x LD_LIBRARY_PATH -x PATH -mca pml ob1 -mca btl ^openib \
	-x NCCL_SOCKET_IFNAME=ens3 -mca btl_tcp_if_exclude lo,docker0 \
	python -W ignore train_imagenet_resnet_hvd.py \
	--model resnet50 --fp16 --num_epochs 2 --warmup_epochs 10 --adv_bn_init \
	--lr 6.4 --lr_decay_mode poly \
	--data_dir ~/data/tf-imagenet/ --log_dir resnet50_log

# Using only 8 gpus for evaluation as we saved checkpoints only on master node
# pass num_gpus it was trained on to print the epoch numbers correctly
/home/ubuntu/anaconda3/envs/tensorflow_p36/bin/mpirun -np 8 -hostfile hosts -mca plm_rsh_no_tree_spawn 1 \
	-bind-to socket -map-by slot \
	-x HOROVOD_HIERARCHICAL_ALLREDUCE=1 -x HOROVOD_FUSION_THRESHOLD=16777216 \
	-x NCCL_MIN_NRINGS=4 -x LD_LIBRARY_PATH -x PATH -mca pml ob1 -mca btl ^openib \
	-x NCCL_SOCKET_IFNAME=ens3 -mca btl_tcp_if_exclude lo,docker0 \
	python -W ignore train_imagenet_resnet_hvd.py \
	--model resnet50 --fp16 --adv_bn_init --num_epochs 2 --num_gpus 16 \
	--data_dir ~/data/tf-imagenet/ --log_dir resnet50_log --eval