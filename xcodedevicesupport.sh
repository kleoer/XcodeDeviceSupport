#!/bin/bash

set -o errexit

# about Xcode
# 
XCODE_DEVICE_SUPPORT_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport"
SDK_SETTINGS_PLIST_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/SDKSettings.plist"
# about cache
# 
CACHE_HOME_PATH="${HOME}/Library/Caches/Kleoer"
DISK_IMAGE_CACHE_PATH="${CACHE_HOME_PATH}/SupportDiskImage"

IOS60="6.0"
IOS61="6.1"
IOS70="7.0"
IOS71="7.1"

SUPPORT_SDK_VERSION="${IOS60} ${IOS61} ${IOS70} ${IOS71}"

DISK_IMAGE_BASE_DOWNLOAD_URL="https://github.com/kleoer/XcodeDeviceSupport/raw/master/DiskImages"

SDK_IOS60_MD5="35e9cf09b70de42f2e4d102bccf66d6c"
SDK_IOS61_MD5="8680a4c609e831f2804a4f77ab4c7a1a"
SDK_IOS70_MD5="7f0a0e580a4644a6645689524d444943"
SDK_IOS71_MD5="24b83d6df3e0eed5d0eba32b06bc1673"

function create_cache_path_if_not_exists()
{
	if [[ ! -d $CACHE_HOME_PATH ]]; then
		mkdir ${CACHE_HOME_PATH}
	fi

	if [[ ! -d $DISK_IMAGE_CACHE_PATH ]]; then
		mkdir ${DISK_IMAGE_CACHE_PATH}
	fi
}

function find_need_disk_image() 
{
	need_images=()

	for image in $@; do
		path="${XCODE_DEVICE_SUPPORT_PATH}/${image}"
		if [[ ! -d $path ]]; then
			need_images[${#need_images[@]}]=$image
		fi
	done
	
	echo ${need_images[@]}
}

function find_need_caches()
{
	need_caches=()

	for image in $@; do

		cache_correct $image
		if [[ $? = 1 ]]; then
			
			need_caches[${#need_caches[@]}]=$image
		fi
		
	done

	echo ${need_caches[@]}
}

function cache_correct()
{
	cache_path="${DISK_IMAGE_CACHE_PATH}/${1}.zip"

	if [[ -f $cache_path ]]; then

		md5=""
		case $1 in

			$IOS60)
				md5=$SDK_IOS60_MD5
				;;
			$IOS61)
				md5=$SDK_IOS61_MD5
				;;
			$IOS70)
				md5=$SDK_IOS70_MD5
				;;
			$IOS71)
				md5=$SDK_IOS71_MD5
				;;
			esac

		if [[ -n $md5 ]]; then
			
			if [[ $(md5 -q $cache_path) = $md5 ]]; then
				
				return 0
			fi
		fi
	fi

	return 1
}

function download_need_caches()
{
	for image_name in $@; do
		image_url="${DISK_IMAGE_BASE_DOWNLOAD_URL}/${image_name}.zip"
		echo "begin download ${image_name}.zip ..."
		
		cache_path=${DISK_IMAGE_CACHE_PATH}/${image_name}.zip
		$(curl -C - -o "${cache_path}" -L $image_url)
		
		cache_correct $image_name
		if [[ $? != 0 ]]; then
			echo "download error, you should run again!"
			rm cache_path

			exit -1
		fi
	done
}

function unzip_disk_images()
{
	for image in $@; do
		cache_path="${DISK_IMAGE_CACHE_PATH}/${image}.zip"
		destination_path="${XCODE_DEVICE_SUPPORT_PATH}/${image}"

		sudo unzip -o $cache_path -d $destination_path
	done
}

function add_deployment_target_suggested_values()
{

	items=$(/usr/libexec/PlistBuddy -c 'Print:DefaultProperties:DEPLOYMENT_TARGET_SUGGESTED_VALUES' $SDK_SETTINGS_PLIST_PATH)
	items=${items#*{}
	items=${items%\}*}

	add_images=()
	for image in $@; do
		if [[ ! $items =~ $image ]]; then
			add_images[${#add_images[@]}]=$image
		fi
	done
	
	add_images=$(echo ${add_images[@]} | tr ' ' '\n' | sort -r)
	for image in $add_images; do

		exec_script="sudo /usr/libexec/PlistBuddy -c 'Add:DefaultProperties:DEPLOYMENT_TARGET_SUGGESTED_VALUES:0 string \"${image}\"' ${SDK_SETTINGS_PLIST_PATH}"
		eval $exec_script
	done
}

function run()
{
	create_cache_path_if_not_exists

	need_images=$(find_need_disk_image $SUPPORT_SDK_VERSION)

	need_caches=$(find_need_caches $need_images)

	download_need_caches $need_caches

	unzip_disk_images $need_images

	add_deployment_target_suggested_values $SUPPORT_SDK_VERSION
}

run


