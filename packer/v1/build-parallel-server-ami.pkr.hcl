# Copyright 2024-2026 The MathWorks, Inc.

# Below is the required plugins statement which is necessary when performing a Packer build
# using Packer v1.10 or later
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "RELEASE" {
  type        = string
  default     = "R2025b"
  description = "Target MATLAB release to install in the machine image, must start with \"R\"."

  validation {
    condition     = can(regex("^R20[0-9][0-9](a|b)(U[0-9])?$", var.RELEASE))
    error_message = "The RELEASE value must be a valid MATLAB release, starting with \"R\"."
  }
}

variable "PRODUCTS" {
  type        = string
  default     = "5G_Toolbox AUTOSAR_Blockset Aerospace_Blockset Aerospace_Toolbox Antenna_Toolbox Audio_Toolbox Automated_Driving_Toolbox Bioinformatics_Toolbox Bluetooth_Toolbox C2000_Microcontroller_Blockset Communications_Toolbox Computer_Vision_Toolbox Control_System_Toolbox Curve_Fitting_Toolbox DDS_Blockset DSP_HDL_Toolbox DSP_System_Toolbox Database_Toolbox Datafeed_Toolbox Deep_Learning_HDL_Toolbox Deep_Learning_Toolbox Econometrics_Toolbox Embedded_Coder Financial_Instruments_Toolbox Financial_Toolbox Fixed-Point_Designer Fuzzy_Logic_Toolbox GPU_Coder Global_Optimization_Toolbox HDL_Coder HDL_Verifier Image_Acquisition_Toolbox Image_Processing_Toolbox Industrial_Communication_Toolbox Instrument_Control_Toolbox LTE_Toolbox Lidar_Toolbox MATLAB MATLAB_Coder MATLAB_Compiler MATLAB_Compiler_SDK MATLAB_Parallel_Server MATLAB_Report_Generator MATLAB_Test Mapping_Toolbox Medical_Imaging_Toolbox Mixed-Signal_Blockset Model_Predictive_Control_Toolbox Motor_Control_Blockset Navigation_Toolbox Optimization_Toolbox Parallel_Computing_Toolbox Partial_Differential_Equation_Toolbox Phased_Array_System_Toolbox Powertrain_Blockset Predictive_Maintenance_Toolbox RF_Blockset RF_PCB_Toolbox RF_Toolbox ROS_Toolbox Radar_Toolbox Reinforcement_Learning_Toolbox Requirements_Toolbox Risk_Management_Toolbox Robotics_System_Toolbox Robust_Control_Toolbox Satellite_Communications_Toolbox Sensor_Fusion_and_Tracking_Toolbox SerDes_Toolbox Signal_Integrity_Toolbox Signal_Processing_Toolbox SimBiology SimEvents Simscape Simscape_Battery Simscape_Driveline Simscape_Electrical Simscape_Fluids Simscape_Multibody Simulink Simulink_3D_Animation Simulink_Check Simulink_Coder Simulink_Compiler Simulink_Control_Design Simulink_Coverage Simulink_Design_Optimization Simulink_Design_Verifier Simulink_Desktop_Real-Time Simulink_Fault_Analyzer Simulink_PLC_Coder Simulink_Real-Time Simulink_Report_Generator Simulink_Test SoC_Blockset Stateflow Statistics_and_Machine_Learning_Toolbox Symbolic_Math_Toolbox System_Composer System_Identification_Toolbox Text_Analytics_Toolbox UAV_Toolbox Vehicle_Dynamics_Blockset Vehicle_Network_Toolbox Vision_HDL_Toolbox WLAN_Toolbox Wavelet_Toolbox Wireless_HDL_Toolbox Wireless_Testbench"
  description = "Target products to install in the machine image, e.g. MATLAB SIMULINK."
}

variable "SPKGS" {
  type        = string
  default     = "Deep_Learning_Toolbox_Model_for_AlexNet_Network Deep_Learning_Toolbox_Model_for_EfficientNet-b0_Network Deep_Learning_Toolbox_Model_for_GoogLeNet_Network Deep_Learning_Toolbox_Model_for_ResNet-101_Network Deep_Learning_Toolbox_Model_for_ResNet-18_Network Deep_Learning_Toolbox_Model_for_ResNet-50_Network Deep_Learning_Toolbox_Model_for_Inception-ResNet-v2_Network Deep_Learning_Toolbox_Model_for_Inception-v3_Network Deep_Learning_Toolbox_Model_for_DenseNet-201_Network Deep_Learning_Toolbox_Model_for_Xception_Network Deep_Learning_Toolbox_Model_for_MobileNet-v2_Network Deep_Learning_Toolbox_Model_for_Places365-GoogLeNet_Network Deep_Learning_Toolbox_Model_for_NASNet-Large_Network Deep_Learning_Toolbox_Model_for_NASNet-Mobile_Network Deep_Learning_Toolbox_Model_for_ShuffleNet_Network Deep_Learning_Toolbox_Model_for_DarkNet-19_Network Deep_Learning_Toolbox_Model_for_DarkNet-53_Network Deep_Learning_Toolbox_Model_for_VGG-16_Network Deep_Learning_Toolbox_Model_for_VGG-19_Network"
  description = "Target products to install in the machine image, e.g. MATLAB SIMULINK."
}

variable "POLYSPACE_PRODUCTS" {
  type        = string
  default     = "Polyspace_Bug_Finder_Server Polyspace_Code_Prover_Server"
  description = "Target product names for Polyspace"
}

variable "POLYSPACE_ROOT" {
  type        = string
  default     = ""
  description = "URL for polyspace root location."
}

variable "BASE_AMI_NAME" {
  type        = string
  default     = "Windows_Server-2022-English-Full-Base-*"
  description = "Default AMI name refers to the Windows Server 2022 image provided by Microsoft."
}

variable "BUILD_SCRIPTS" {
  type = list(string)
  default = [
    "Install-Dependencies.ps1",
    "Install-StartupScripts.ps1",
    "Install-NVIDIA-Drivers.ps1",
    "Install-RuntimeScripts.ps1",
    "Install-MATLAB.ps1",
    "Setup-SupportPackagesRoot.ps1",
    "Install-SupportPackages.ps1",
    "Remove-IE.ps1",
    "New-ToolboxCache.ps1"
  ]
  description = "The list of installation scripts Packer will use when building the image."
}

variable "STARTUP_SCRIPTS" {
  type = list(string)
  default = [
    "env.ps1",
    "10_Setup-Disks.ps1",
    "20_Setup-MATLAB.ps1",
    "30_Setup-Polyspace.ps1",
    "40_WarmUp-MATLAB.ps1",
    "50_Edit-MJS-Def.ps1",
    "60_Sync-MJS-Files.ps1",
    "65_Run-Optional-User-Command.ps1",
    "70_Start-MJS.ps1",
    "80_Add-SpotInstanceMonitoring.ps1"
  ]
  description = "The list of startup scripts Packer will copy to the remote machine image builder, which can be used during the CloudFormation Stack creation."
}

variable "RUNTIME_SCRIPTS" {
  type = list(string)
  default = [
    "autoscaling",
    "mwplatforminterfaces",
    "spotinstances"
  ]
  description = "The list of runtime script directories Packer will copy to the remote machine image builder, which can be used after the CloudFormation Stack creation."
}

variable "NVIDIA_DRIVER_INSTALLER_URL" {
  type        = string
  default     = "https://us.download.nvidia.com/tesla/538.15/538.15-data-center-tesla-desktop-winserver-2019-2022-dch-international.exe"
  description = "The URL to install NVIDIA drivers into the target machine image."
}

variable "PYTHON_INSTALLER_URL" {
  type        = string
  default     = "https://www.python.org/ftp/python/3.10.5/python-3.10.5-amd64.exe"
  description = "The URL to install python into the target machine image."
}

variable "MATLAB_SOURCE_URL" {
  type        = string
  default     = ""
  description = "Optional URL from which to download a MATLAB and toolbox source file, for use with the mpm --source option."
}

variable "SUPPORT_PACKAGE_URL" {
  type        = string
  default     = ""
  description = "Location of the support package zip."
}

variable "MSA_URL" {
  type        = string
  description = "URL pointing to a valid MATLAB Startup Accelerator file. If left unset, a default URL will be constructed based on the RELEASE variable."
  default     = null
}

# The following variables share the same setup across all MATLAB releases.
variable "VPC_ID" {
  type        = string
  default     = ""
  description = "The target AWS VPC to be used by Packer. If not specified, Packer will use default VPC."

  validation {
    condition     = length(var.VPC_ID) == 0 || substr(var.VPC_ID, 0, 4) == "vpc-"
    error_message = "The VPC_ID must start with \"vpc-\"."
  }
}

variable "SUBNET_ID" {
  type        = string
  default     = ""
  description = "The target subnet to be used by Packer. If not specified, Packer will use the subnet that has the most free IP addresses."

  validation {
    condition     = length(var.SUBNET_ID) == 0 || substr(var.SUBNET_ID, 0, 7) == "subnet-"
    error_message = "The SUBNET_ID must start with \"subnet-\"."
  }
}

variable "SECURITY_GROUP_ID" {
  type        = string
  default     = ""
  description = "(Optional) The target security group to be used by Packer. If not specified, Packer will create a temporary security group."
}

variable "INSTANCE_TAGS" {
  type = map(string)
  default = {
    Name  = "Packer Builder"
    Build = "MATLAB"
  }
  description = "The tags Packer adds to the machine image builder."
}

variable "AMI_TAGS" {
  type = map(string)
  default = {
    Name          = "PackerBuild"
    Build         = "matlab-parallel-server"
    Type          = "matlab-parallel-server-on-aws-win"
    Platform      = "Windows"
    Base_AMI_ID   = "{{ .SourceAMI }}"
    Base_AMI_Name = "{{ .SourceAMIName }}"
  }
  description = "The tags Packer adds to the resultant machine image."
}

variable "AWS_ACCESS_USERS" {
  type        = list(string)
  default     = []
  description = "The list of accounts that have access to launch the resulting AMI."
}

variable "MANIFEST_OUTPUT_FILE" {
  type        = string
  default     = "manifest.json"
  description = "The name of the resultant manifest file."
}

variable "PACKER_ADMIN_USERNAME" {
  type        = string
  default     = "Administrator"
  description = "Username for the build instance."
}

variable "MICROSOFT_DIRECTX_URL" {
  type        = string
  default     = "https://download.microsoft.com/download/1/7/1/1718CCC4-6315-4D8E-9543-8E28A4E18C4C/dxwebsetup.exe"
  description = "The URL of the Microsoft DirectX download"
}

# Optional parameters to setup a SSH Bastion for Packer Build
variable "SSH_BASTION_HOST" {
  type        = string
  default     = ""
  description = "(Optional) A bastion host to use for the actual SSH connection."
}

variable "SSH_INTERFACE" {
  type         = string
  default      = "public_ip"
  description  = "Specifies the type of network interface address used by Packer for SSH connections. Acceptable values are 'public_ip', 'private_ip', 'public_dns', or 'private_dns'."
}

variable "SSH_BASTION_USERNAME" {
  type        = string
  default     = ""
  description = "(Optional) The username to connect to the bastion host."
}

variable "SSH_BASTION_PRIVATE_KEY_FILE" {
  type        = string
  default     = ""
  description = "(Optional) Path to a PEM encoded private key file to use to authenticate with the bastion host."
}

variable "AWS_INSTANCE_PROFILE" {
  type        = string
  default     = ""
  description = "The AWS instance profile role used during Packer builds."
}

# Set up local variables used by provisioners.
locals {
  timestamp             = regex_replace(timestamp(), "[- TZ:]", "")
  build_scripts         = [for s in var.BUILD_SCRIPTS : format("build/%s", s)]
  startup_scripts       = [for s in var.STARTUP_SCRIPTS : format("startup/%s", s)]
  runtime_scripts       = [for s in var.RUNTIME_SCRIPTS : format("runtime/%s", s)]
  packer_admin_username = "${var.PACKER_ADMIN_USERNAME}"
  use_temp_sg_rule      = var.SECURITY_GROUP_ID == "" ? true : false
  # This local variable decides which URL to use.
  # If var.MSA_URL is not null (meaning the user provided an override), use that value.
  # Otherwise, construct the URL using var.RELEASE.
  effective_msa_url = var.MSA_URL != null ? var.MSA_URL : "https://raw.githubusercontent.com/mathworks-ref-arch/iac-building-blocks/refs/heads/main/common/artifacts/msa/${var.RELEASE}/Windows/msa.ini"
}

# Configure the EC2 instance that is used to build the machine image.
source "amazon-ebs" "AMI_Builder" {
  ami_name = "CustomPacker-matlab-${var.RELEASE}-${local.timestamp}"
  aws_polling {
    delay_seconds = 60
    max_attempts  = 300
  }
  
  # Communicator setup
  ssh_username                 = "${var.PACKER_ADMIN_USERNAME}"
  ssh_interface                = "${var.SSH_INTERFACE}"
  ssh_timeout                  = "10m" 

  # Optional bastion host configuration
  ssh_bastion_host             = "${var.SSH_BASTION_HOST}"
  ssh_bastion_username         = "${var.SSH_BASTION_USERNAME}"
  ssh_bastion_private_key_file = "${var.SSH_BASTION_PRIVATE_KEY_FILE}"

  # Networking configuration
  vpc_id                       = "${var.VPC_ID}"
  subnet_id                    = "${var.SUBNET_ID}"

  # If VPC/subnet not set, Packer will choose VPC and Subnet according to these filters
  vpc_filter {
    filters = {
      isDefault = true
    }
  }
  subnet_filter {
    most_free = true
    random    = false
  }

  # Optional: Provide ID of an existing security group
  security_group_id  = "${var.SECURITY_GROUP_ID}"

  # If no security group provided, allow Packer to create a temporary security group
  # that allows SSH access from the host's public IP
  temporary_security_group_source_public_ip = "${local.use_temp_sg_rule}"

  # Packer builder specifications
  instance_type = "g4dn.xlarge"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    volume_size           = 128
    volume_type           = "gp2"
  }
  region = "us-east-1"
  source_ami_filter {
    filters = {
      "virtualization-type" = "hvm"
      "name"                = "${var.BASE_AMI_NAME}"
      "root-device-type"    = "ebs"
    }
    owners      = ["801119661308"] # Owner ID associated with Windows Server AMIs
    most_recent = true
  }
  iam_instance_profile = "${var.AWS_INSTANCE_PROFILE}"
  # Grants the Packer builder instance permission to download NVIDIA Grid Drivers from the official AWS S3 bucket.
  # Append any additional IAM permissions required by your provisioning scripts to this policy block.
  temporary_iam_instance_profile_policy_document {
    Version = "2012-10-17"
    Statement {
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*",
        "s3:Describe*",
      ]
      Resource = ["arn:aws:s3:::ec2-windows-nvidia-drivers/latest/*", "arn:aws:s3:::ec2-windows-nvidia-drivers"]
    }
  }
  ami_users            = "${var.AWS_ACCESS_USERS}"
  snapshot_users       = "${var.AWS_ACCESS_USERS}"

  run_tags                                  = "${var.INSTANCE_TAGS}"
  tags                                      = "${var.AMI_TAGS}"

  # Inject SSH setup script as user-data
  user_data        = templatefile("build/config/packer/enable_openssh.pkrtpl.hcl", {})
}

build {
  sources = ["source.amazon-ebs.AMI_Builder"]

  provisioner "file" {
    destination = "C:/Windows/Temp/"
    source      = "build/config"
    max_retries = 3
  }

  provisioner "powershell" {
    inline      = [for s in local.runtime_scripts : "mkdir C:Windows/Temp/${s}"]
    max_retries = 3
  }

  # Copy the entire runtime directory to the target machine
  provisioner "file" {
    source      = "runtime"
    destination = "C:/Windows/Temp"
    max_retries = 3
  }

  provisioner "powershell" {
    inline      = ["mkdir C:/Windows/Temp/startup"]
    max_retries = 3
  }

  provisioner "file" {
    destination = "C:/Windows/Temp/startup/"
    sources     = "${local.startup_scripts}"
    max_retries = 3
  }

  provisioner "powershell" {
    environment_vars = [
      "NVIDIA_DRIVER_INSTALLER_URL=${var.NVIDIA_DRIVER_INSTALLER_URL}",
      "MICROSOFT_DIRECTX_URL=${var.MICROSOFT_DIRECTX_URL}",
      "RELEASE=${var.RELEASE}",
      "PRODUCTS=${var.PRODUCTS}",
      "SPKGS=${var.SPKGS}",
      "POLYSPACE_PRODUCTS=${var.POLYSPACE_PRODUCTS}",
      "PYTHON_INSTALLER_URL=${var.PYTHON_INSTALLER_URL}",
      "MATLAB_SOURCE_URL=${var.MATLAB_SOURCE_URL}",
      "MSA_URL=${local.effective_msa_url}",
      "SUPPORT_PACKAGE_URL=${var.SUPPORT_PACKAGE_URL}",
    ]
    scripts      = "${local.build_scripts}"
    pause_before = "2m"
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'System restarted.'}\""
    restart_timeout       = "10m"
  }

  provisioner "powershell" {
    scripts = [
      "build/Remove-TemporaryFiles.ps1",
      "build/Invoke-Sysprep.ps1"
      ]
      pause_before = "1m"
  }

  post-processor "manifest" {
    output     = "${var.MANIFEST_OUTPUT_FILE}"
    strip_path = true
    custom_data = {
      release                      = "MATLAB ${var.RELEASE}"
      specified_products           = "${var.PRODUCTS}"
      specified_spkgs              = "${var.SPKGS}"
      specified_polyspace_products = "${var.POLYSPACE_PRODUCTS}"
      build_scripts                = join(", ", "${var.BUILD_SCRIPTS}")
      base_ami_id                  = "{{ .SourceAMI }}"
      base_ami_name                = "{{ .SourceAMIName }}"
    }
  }
}
