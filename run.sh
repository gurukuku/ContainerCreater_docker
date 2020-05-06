#!/bin/bash

lognum=1
longStr=""
tmptxt=$(mktemp tmpfileXXXX.txt)

function logblock {
        local text=$1
        printf "%03d:%s : " "$lognum" "$text" >> log.txt
        printf "%03d:%s\n" "$lognum" "$text" >> error.txt
        lognum=$[ $lognum+1 ]
}

function getField {
        echo "$1" | awk -v idx=$2 -F"|" '{print $idx}'
}

function programEnd {
        echo "" >> log.txt
        echo "Program end" >> log.txt

        rm -f $tmptxt > /dev/null 2> /dev/null

        clear
	if [ $# -eq 1 ]
        then
                echo -e "$1"
        fi

        exit
}

function checkModule {
	#check module(docker)
        logblock "check module(docker)"
        if ! docker version > /dev/null 2>> error.txt
        then #not exist docker
                echo "not exist" >> log.txt
                logblock "download module(docker)"
                echo "download docker..."

                #check internet
                if $cInternet
                then #try download
                        echo "This is very time consuming"

                        apt-get -y update > /dev/null 2>> error.txt

                        #download utils
                        if ! apt-get -y install \
                                apt-transport-https ca-certificates curl software-properties-common \
                                > /dev/null 2>> error.txt
                        then #failed to download utils
                                echo "error" >> log.txt
                                logblock "download module(docker)-retry"

                                rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend

                                #retry download
                                if ! apt-get -y install \
                                        apt-transport-https ca-certificates curl software-properties-common \
                                        > /dev/null 2>> error.txt
                                then #failed to download utils
                                        echo "error" >> log.txt
                                        programEnd "unexpected error!"
                                fi
                        fi

                        #add key
                        curl -fssL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
                                > /dev/null 2>> error.txt

                        #add repository
                        add-apt-repository \
                                "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
                                > /dev/null 2>> error.txt

                        #download docker
                        apt-get -y update > /dev/null 2>> error.txt
                        apt-get -y install docker-ce > /dev/null 2>> error.txt
                        echo "OK" >> log.txt
                else #no internet
                        echo "error" >> log.txt
                        echo "network error" >> error.txt
                        longStr="failed to download docker\n"
                        longStr=$longStr"please check internet connection"
                        programEnd "$longStr"
                fi
        else #exist docker
                echo "exist" >> log.txt
        fi
	
	#check module(dialog)
        logblock "check module(dialog)"
        if [ -z "$(dpkg -l | awk '$2=="dialog"')" ]
        then #not exist dialog
                echo "not exist" >> log.txt
                logblock "download module(dialog)"
                echo "download dialog..."

                #check internet
                if $cInternet
                then #try download
                        echo "This is time consuming"
                        apt-get -y update > /dev/null 2>> error.txt
                        apt-get -y install dialog > /dev/null 2>> error.txt
                        echo "OK" >> log.txt
                else #no internet
                        echo "error" >> log.txt
                        echo "network error" >> error.txt
                        longStr="failed to download dialog\n"
                        longStr=$longStr"please check internet connection"
                        programEnd "$longStr"
                fi
        else #exist dialog
                echo "exist" >> log.txt
        fi
}

function prework {
	cInternet=false
	image=""
	network="null|null"
	volume=""
	name="|"
	link=""

	echo "------------------------------" >> log.txt
	echo "Program start" >> log.txt
	echo "" >> log.txt
	echo "------------------------------" >> error.txt
	
	clear

	#check user
        logblock "check user"
        if [ "$(whoami)" == "root" ]
        then
                echo "root" >> log.txt
        else
                echo "not root" >> log.txt
                echo "not root" >> error.txt
                programEnd "please run as root"
        fi

	#check internet
	logblock "check internet"
	ping -c 3 www.google.com > /dev/null 2>> error.txt
	if [ $? -eq 0 ]
	then
	        echo "connected" >> log.txt
	        cInternet=true
	else
	        echo "not connected" >> log.txt
	fi
	
	checkModule
}

function imageMenu {
        local menuCmd           #command for make menu
        local menuIdx           #menu index starts at 1
        local imageIdx          #index of image list
        local imageName
        local maxMenuIdx        #number of menu element
        local preImageIdx       #number of elements before image
	local inp

        echo "image" >> log.txt

        while true
        do
                #pre-work(set menu)
                logblock "image menu(pre-work)"

                menuCmd="dialog^--menu^image menu^30^50^20"
                menuCmd="$menuCmd^1^download image"
                imageIdx=2
                preImageIdx=$[ $imageIdx - 1 ]

                for imageName in $(docker image ls | awk 'NR >= 2 {print $1":"$2}')
                do
                        menuCmd="$menuCmd^$imageIdx^$imageName"
                        imageIdx=$[ $imageIdx + 1 ]
                done
                imageIdx=$[ $imageIdx - 1 ]

                maxMenuIdx=$[ $imageIdx + 1 ]
                menuCmd="$menuCmd^$maxMenuIdx^back"

                echo "OK" >> log.txt

                #make menu
                tmpIFS=$IFS
                IFS="^"
                $menuCmd 2> $tmptxt
                IFS=$tmpIFS

                #menu
                logblock "image menu"
                menuIdx=$(cat $tmptxt)
                imageIdx=$[ $menuIdx - $preImageIdx ]
                case $menuIdx in
		1) #download image
                        echo "download image" >> log.txt

                        #check internet
                        logblock "check internet"
                        if ! $cInternet
                        then
                                echo "not connected" >> log.txt
                                longStr="failed to download image\n"
                                longStr=$longStr"please check internet connection"
                                dialog --msgbox "$longStr" 10 40
                                continue
                        fi
                        echo "connected" >> log.txt
			
			while true
			do
				#input name
                                logblock "input name"
                                dialog --inputbox "input name" 10 20 2> $tmptxt

                                #check cancel
                                if [ $? -ne 0 ]
                                then
                                        echo "cancel" >> log.txt
					inp=-1
                                        break
                                fi

				imageName=$(cat $tmptxt)

                                #express latest tag
                                if [[ $imageName =~ ^[^:]+$ ]]
                                then
                                        imageName=$imageName":latest"
                                fi

                                #check image name
                                if [[ !  $imageName =~ ^[^:]+[:][^:]+$ ]]
                                then
                                        echo "wrong name($imageName)" >> log.txt
                                        dialog --msgbox "wrong name" 10 20
                                        continue
                                fi

				inp=0
				break
			done
			if [ $inp -eq -1 ]
			then
				continue
			fi

			#find image
                        if [ $(docker image ls | awk 'NR >= 2 {print $1":"$2}' \
	                        | grep "^${imageName}$") ]
                        then #already exist
                                echo "already exist($imageName)" >> log.txt
                                logblock "use this?"

                                longStr="$imageName is already exist\n"
                     		longStr=$longStr"use this image?"

                                dialog --yesno "$longStr" 10 40
                                if [ $? -eq 0 ]
                                then
                                        echo "yes" >> log.txt
                                        image=$imageName
                                        return
                                else
                                        echo "no" >> log.txt
                                                continue
                                        fi
                        elif docker image pull $imageName > /dev/null 2>> error.txt
			then #downloaded
                                echo "OK($imageName)" >> log.txt
                                logblock "use this?"

				longStr="$imageName downloaded\n"
                                longStr=$longStr"use this image?"

                                dialog --yesno "$longStr" 10 40
                                if [ $? -eq 0 ]
                                then
                                        echo "yes" >> log.txt
                                        image=$imageName
                                        return
                                else
                                        echo "no" >> log.txt
                                        continue
                                fi
			else #not found
                                echo "not found($imageName)" >> log.txt
                                dialog --msgbox "$imageName\nnot found" 10 30
                                continue
			fi
                        ;;
		$maxMenuIdx | "") #back or cancel
                        echo "exit" >> log.txt
                        break
                        ;;
                *) #image selected
                        imageName=$(docker image ls | awk 'NR >= 2 {print $1":"$2}' \
                                | awk -v line=$imageIdx 'NR == line')

                        echo "select image($imageName)" >> log.txt

                        image=$imageName
                        break
                        ;;
                esac
        done
}

function networkMenu {
        local menuCmd
        local menuIdx
        local networkIdx
        local networkName
        local maxMenuIdx
        local preNetworkIdx
	local inp

        echo "network" >> log.txt

        while true
        do
                #pre-work(set menu)
                logblock "network menu(pre-work)"

                menuCmd="dialog^--menu^network menu^30^50^20"
                menuCmd="$menuCmd^1^create network^2^port mapping"
                networkIdx=3
                preNetworkIdx=$[ $networkIdx - 1 ]

                for networkName in $(docker network ls | awk 'NR >= 2 {print $2}')
                do
                        menuCmd="$menuCmd^$networkIdx^$networkName"
                        networkIdx=$[ $networkIdx + 1 ]
                done
                networkIdx=$[ $networkIdx - 1 ]

                maxMenuIdx=$[ $networkIdx + 2 ]
                menuCmd="$menuCmd^$[ $maxMenuIdx - 1 ]^reset^$maxMenuIdx^back"

                echo "OK" >> log.txt

                #make menu
                tmpIFS=$IFS
                IFS="^"
                $menuCmd 2> $tmptxt
                IFS=$tmpIFS

                #menu
                logblock "network menu"
                menuIdx=$(cat $tmptxt)
                networkIdx=$[ $menuIdx - $preNetworkIdx ]
                case $menuIdx in
                1) #create network
			echo "create network" >> log.txt

			while true
			do
				logblock "input nic"
                                dialog --form "create network" 15 50 5 \
                                        "name"		1 1 "" 1 20 20 0 \
					"subnet"	2 1 "" 2 20 20 0 \
					"gateway"	3 1 "" 3 20 20 0 \
                                        2> $tmptxt

				#check cancel
                                if [ $? -ne 0 ]
                                then
                                        echo "cancel" >> log.txt
					inp=-1
                                        break
                                fi
				
				local netName=$(cat $tmptxt | awk 'NR == 1 {print $0}')
                                local netSubnet=$(cat $tmptxt | awk 'NR == 2 {print $0}')
				local netGateway=$(cat $tmptxt | awk 'NR == 3 {print $0}')

                                echo "input" >> log.txt

				#check name
				if [[ ! "$netName" =~ ^[0-9a-zA-Z_\-]+$ ]]
				then
					echo "    wrone name : $netName" >> log.txt
					dialog --msgbox "wrong input\n$netName" 10 20
					continue
				fi

				#check subnet
                                if [[ ! "$netSubnet" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]
                                then
                                        echo "    wrone subnet : $netSubnet" >> log.txt
                                        dialog --msgbox "wrong input\n$netSubnet" 10 20
                                        continue
                                fi

				#check gateway
                                if [[ ! "$netGateway" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
                                then
                                        echo "    wrone gateway : $netGateway" >> log.txt
                                        dialog --msgbox "wrong input\n$netGateway" 10 20
                                        continue
                                fi

				if [ "$netSubnet" != "" ]
				then
					netSubnet="--subnet $netSubnet"
				fi

				if [ "$netGateway" != "" ]
	                        then
	                                netGateway="--gateway $netGateway"
	                        fi

				logblock "create network"

				#check network
	                        if [ $(docker network ls | awk 'NR >= 2 {print $2}' \
	                                | grep "^${netName}$") ]
	                        then #already exist
	                                echo "already exist($netName)" >> log.txt
	                                dialog --msgbox "$netName is already exist" 10 40
	                                continue
	                        elif docker network create $netSubnet $netGateway $netName > /dev/null 2>> error.txt
	                        then #created
	                                echo "OK($netName)" >> log.txt
	                                logblock "use this?"

	                                longStr="$netName created\n"
	                                longStr=$longStr"use this network?"
	
                        	        dialog --yesno "$longStr" 10 40
                        	        if [ $? -eq 0 ]
                        	        then
                        	                echo "yes" >> log.txt
                        	                networkName=$netName
						inp=0
                        	        else
                        	                echo "no" >> log.txt
                        	                inp=-1
                        	        fi

					break
                        	else #error
					echo "can't create($netName)" >> log.txt
                        	        dialog --msgbox "failed to create $netName" 10 40
                        	        inp=-1
					break
                        	fi
			done
                        if [ $inp -eq -1 ]
                        then
                                continue
                        fi
                        ;;
                2) #port mapping
			echo "port mapping" >> log.txt

                        while true
                        do
                                logblock "port mapping"
                                dialog --form "port mapping" 15 40 5 \
                                        "host port"             1 1 "" 1 20 10 0 \
                                        "container port"        2 1 "" 2 20 10 0 \
                                        2> $tmptxt

                                #check cancel
                                if [ $? -ne 0 ]
                                then
                                        echo "cancel" >> log.txt
                                        break
                                fi

                                local hostPort=$(cat $tmptxt | awk 'NR == 1 {print $0}')
                                local ctnPort=$(cat $tmptxt | awk 'NR == 2 {print $0}')

                                echo "input" >> log.txt

                                #check host port
                                if [[ ! "$hostPort" =~ ^[0-9]+$ ]]
                                then
                                        echo "    wrong host port : $hostPort" >> log.txt
                                        dialog --msgbox "wrong input\n$hostPort" 10 20
                                        continue
                                fi

                                #check ctn port
                                if [[ ! "$ctnPort" =~ ^[0-9]+$ ]]
                                then
                                        echo "    wrong ctn port : $ctnPort" >> log.txt
                                        dialog --msgbox "wrong input\n$ctnPort" 10 20
                                        continue
                                fi

                                network="p|$hostPort:$ctnPort"
                                return
                        done
                        continue
                        ;;
		$[ $maxMenuIdx - 1 ]) #reset
                        echo "reset" >> log.txt
                        network="null|null"
                        return
                        ;;
                $maxMenuIdx | "") #back or cancel
                        echo "exit" >> log.txt
                        return
                        ;;
                *) #network selected
                        networkName=$(docker network ls | awk 'NR >= 2 {print $2}' \
                                | awk -v line=$networkIdx 'NR == line')

                        echo "select network($networkName)" >> log.txt

                        #check custom
                        logblock "costom?"
                        if [ "$networkName" == "bridge" ] || [ "$networkName" == "host" ] \
                                || [ "$networkName" == "none" ]
                        then
                                echo "no" >> log.txt
                                network="n|$networkName|null"
                                return
                        else
                                echo "yes" >> log.txt
                        fi
                        ;;
                esac

                #input ip
                while true
                do
                        logblock "input ip"
                        dialog --inputbox \
                                "input ip (x.x.x.x)\n(skip with blank)" 10 30 2> $tmptxt

                        #check cancel
                        if [ $? -ne 0 ]
                        then
                                echo "cancel" >> log.txt
                                break
                        fi

                        local networkip=$(cat $tmptxt)
			
                        #check ip
                        if [ "$networkip" == "" ]
                        then #skip
                                echo "skip" >> log.txt
                                network="n|$networkName|null"
                                return
                        elif [[ !  $networkip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
                        then #wrone input
                                echo "wrong input($networkip)" >> log.txt
                                dialog --msgbox "wrong input\n$networkip" 10 20
                                continue
			else #OK
				echo "OK($networkip)" >> log.txt
                        	network="n|$networkName|$networkip"
                        	return
                        fi
                done
        done
}

function volumeMenu {
        local menuCmd
        local menuIdx
        local volumeIdx
        local volumeName
        local maxMenuIdx
        local preVolumeIdx

        echo "volume" >> log.txt

        while true
        do
                #pre-work(set menu)
                logblock "volume menu(pre-work)"

                menuCmd="dialog^--menu^volume menu^30^50^20"
                menuCmd="$menuCmd^1^create volume^2^directory mapping"
                volumeIdx=3
                preVolumeIdx=$[ $volumeIdx - 1 ]

                for volumeName in $(docker volume ls | awk 'NR >= 2 {print $2}')
                do
                        menuCmd="$menuCmd^$volumeIdx^$volumeName"
                        volumeIdx=$[ $volumeIdx + 1 ]
                done
                volumeIdx=$[ $volumeIdx - 1 ]

                maxMenuIdx=$[ $volumeIdx + 2 ]
                menuCmd="$menuCmd^$[ $maxMenuIdx - 1 ]^reset^$maxMenuIdx^back"

                echo "OK" >> log.txt

                #make menu
                tmpIFS=$IFS
                IFS="^"
                $menuCmd 2> $tmptxt
                IFS=$tmpIFS

                #menu
                logblock "volume menu"
                menuIdx=$(cat $tmptxt)
                volumeIdx=$[ $menuIdx - $preVolumeIdx ]
                case $menuIdx in
                1) #create volume
			echo "create volume" >> log.txt

			#input volume name
                        logblock "input volume name"
                        dialog --inputbox "input volume name" 10 30 2> $tmptxt

                        #check cancel
                       	if [ $? -ne 0 ]
                        then
                                echo "cancel" >> log.txt
                                continue
                        fi

                        volumeName=$(cat $tmptxt)

			#check volume
                        if [ $(docker volume ls | awk 'NR >= 2 {print $2}' \
                                | grep "^${volumeName}$") ]
                        then #already exist
                                echo "already exist($volumeName)" >> log.txt
                                logblock "use this?"

                                longStr="$volumeName is already exist\n"
                                longStr=$longStr"use this volume?"

                                dialog --yesno "$longStr" 10 30
                                if [ $? -eq 0 ]
                                then
                                        echo "yes" >> log.txt
                                else
                                        echo "no" >> log.txt
                                        continue
                                fi
                        elif docker volume create $volumeName > /dev/null 2>> error.txt
                        then #created
                                echo "OK($volumeName)" >> log.txt
                                logblock "use this?"

                                longStr="$volumeName created\n"
                                longStr=$longStr"use this volume?"

                                dialog --yesno "$longStr" 10 30
                                if [ $? -eq 0 ]
                                then
                                        echo "yes" >> log.txt
                                else
                                        echo "no" >> log.txt
                                        continue
                                fi
                        else #error
                                echo "can't create($volumeName)" >> log.txt
                                dialog --msgbox "failed to create $volumeName" 10 40
                                continue
                        fi

			#input ctn directory
                        logblock "input ctn directory"
                        dialog --title "container directory" \
                                --inputbox "input directory" 10 30 2> $tmptxt

                        #check cancel
                        if [ $? -ne 0 ]
                        then
                                echo "cancel" >> log.txt
                                continue
                        fi

			echo "OK" >> log.txt

                        volume=$(cat $tmptxt)
			break
                        ;;
                2) #directory mapping
                        echo "directory mapping" >> log.txt

                        #input host directory
                        logblock "input host directory"
                        dialog --title "host Directory" --dselect / 10 30 2> $tmptxt

                        #check cancel
                        if [ $? -ne 0 ]
                        then
                                echo "cancel" >> log.txt
                                continue
                        fi

                        volumeName=$(cat $tmptxt)

                        #input ctn directory
                        logblock "input ctn directory"
                        dialog --title "container directory" \
                                --inputbox "input directory" 10 30 2> $tmptxt

                        #check cancel
                        if [ $? -ne 0 ]
                        then
                                echo "cancel" >> log.txt
                                continue
                        fi

                        volumeName="$volumeName:$(cat $tmptxt)"

                        echo "OK" >> log.txt

                        volume=$volumeName
                        break
                        ;;
		$[ $maxMenuIdx - 1 ]) #reset
                        echo "reset" >> log.txt
                        volume=""
                        break
                        ;;
                $maxMenuIdx | "") #back or cancel
                        echo "exit" >> log.txt
                        break
                        ;;
                *) #volume selected
                        volumeName=$(docker volume ls | awk 'NR >= 2 {print $2}' \
                                | awk -v line=$volumeIdx 'NR == line')

                        echo "select volume($volumeName)" >> log.txt

                        #input ctn directory
                        logblock "input ctn directory"
                        dialog --title "container directory" \
                                --inputbox "input directory" 10 30 2> $tmptxt

                        #check cancel
                        if [ $? -ne 0 ]
                        then
                                echo "cancel" >> log.txt
                                continue
                        fi

                        volumeName="$volumeName:$(cat $tmptxt)"

                        echo "OK" >> log.txt
                        volume=$volumeName
                        break
                        ;;
                esac
        done
}

function nameMenu {
        local nameCmd
        local hostnameCmd

        echo "name" >> log.txt

        while true
        do
                logblock "name menu"

                #make menu
                dialog --form "set name\n(skip with blank)" 15 40 5 \
                        "name"          1 1 "" 1 15 15 0 \
                        "hostname"      2 1 "" 2 15 15 0 \
                        2> $tmptxt

                #check cancel
                if [ $? -ne 0 ]
                then
                        echo "cancel" >> log.txt
                        return
                fi

                nameCmd=$(cat $tmptxt | awk 'NR == 1 {print $0}')
                hostnameCmd=$(cat $tmptxt | awk 'NR == 2 {print $0}')

                echo "input" >> log.txt

                #check name
                if [ "$nameCmd" == "" ]
                then #skip
                        echo "    skip name" >> log.txt
                elif [[ ! "$nameCmd" =~ ^[0-9a-zA-Z_\-]+$ ]]
                then #wrong name
                        echo "    wrong name : $nameCmd" >> log.txt
                        dialog --msgbox "wrong name\n$nameCmd" 10 20
                        continue
                elif docker container ls \
                        | awk 'NR >= 2 {print $NF}' | grep "^${nameCmd}$" \
			> /dev/null 2> error.txt
                then #duplicate names
                        echo "    duplicate names : $nameCmd" >> log.txt
                        dialog --msgbox "$nameCmd is already exist" 10 20
                        continue
                else #ok
                        echo "    name : $nameCmd" >> log.txt
                fi

                #check hostname

                if [ "$hostnameCmd" == "" ]
                then #skip
                        echo "    skip hostname" >> log.txt
                elif [[ ! "$hostnameCmd" =~ ^[0-9a-zA-Z_\-]+$ ]]
                then #wrong hostname
                        echo "    wrong hostname : $hostnameCmd" >> log.txt
                        dialog --msgbox "wrong hostname\n$hostnameCmd" 10 20
                        continue
                else #ok
                        echo "    hostname : $hostnameCmd" >> log.txt
                fi

                name="$nameCmd|$hostnameCmd"
                break
        done
}

function linkMenu {
        local menuCmd
        local menuIdx
        local containerIdx
        local containerName
        local maxMenuIdx

        echo "link" >> log.txt

        #pre-work(set menu)
        logblock "link menu(pre-work)"

        menuCmd="dialog^--menu^select container^30^50^20"
        containerIdx=1

        for containerName in $(docker container ls | awk 'NR >= 2 {print $NF}')
        do
                menuCmd="$menuCmd^$containerIdx^$containerName"
                containerIdx=$[ $containerIdx + 1 ]
        done
        containerIdx=$[ $containerIdx - 1 ]

        maxMenuIdx=$[ $containerIdx + 2 ]
        menuCmd="$menuCmd^$[$maxMenuIdx - 1]^reset^$maxMenuIdx^back"

        echo "OK" >> log.txt

        #make menu
        local tmpIFS=$IFS
        IFS="^"
        $menuCmd 2> $tmptxt
        IFS=$tmpIFS

        #menu
        logblock "link menu"

        menuIdx=$(cat $tmptxt)
        containerIdx=$menuIdx

        case $menuIdx in
        $[$maxMenuIdx - 1]) #reset
                echo "reset" >> log.txt
                link=""
                ;;
        $maxMenuIdx | "") #cancel
                echo "exit" >> log.txt
                ;;
        *) #container selected
                containerName=$(docker container ls | awk 'NR >= 2 {print $NF}' \
                                | awk -v line=$containerIdx 'NR == line')
                echo "select container($containerName)" >> log.txt
                link="$containerName"
                ;;
        esac
}

function createMenu {
        local menuIdx
        local createCmd
        local option
        local optionPrm

        echo "create" >> log.txt

        logblock "set image"
        if [ "$image" == "" ]
        then
                echo "no" >> log.txt
                dialog --msgbox "no image set\ncan't create container" 10 30
		return
        fi
        echo "yes" >> log.txt

        #make menu
        dialog --menu "connect option" 20 30 15 \
                1 "console connect" 2 "background" 3 "back" 2> $tmptxt

        #menu
        logblock "create menu"
        menuIdx=$(cat $tmptxt)
        case $menuIdx in
        1)
                echo "console connect" >> log.txt
                option="-it"
                optionPrm="/bin/bash"
                ;;
        2)
                echo "background" >> log.txt
                option="-d"
                optionPrm=""
                ;;
        3 | "") #back or cancel
                echo "exit" >> log.txt
		return
                ;;
        esac

        createCmd="docker run $option"

        #name command set
        if [ "$(getField $name 1)" != "" ]
        then
                createCmd="$createCmd --name $(getField $name 1)"
        fi

        #hostname command set
        if [ "$(getField $name 2)" != "" ]
        then
                createCmd="$createCmd --hostname $(getField $name 2)"
        fi

        #network command set
        if [ "$(getField $network 1)" == "n" ]
        then
                if [ "$(getField $network 3)" != "null" ]
                then
                        createCmd="$createCmd --network $(getField $network 2) --ip $(getField $network 3)"
                else
                        createCmd="--network $(getField $network 2)"
                fi
        elif [ "$(getField $network 1)" == "p" ]
        then
                createCmd="$createCmd -p $(getField $network 2)"
        fi

        #volume command set
        if [ "$volume" != "" ]
        then
                createCmd="$createCmd -v $volume"
        fi

        #link command set
        if [ "$link" != "" ]
        then
                createCmd="$createCmd -v $link:$link"
        fi

        createCmd="$createCmd $image $optionPrm"
	
        logblock "command execute"
	if [ "$option" == "-d" ]
	then
		if $createCmd > /dev/null 2>> error.txt
		then
			echo "OK(-d)" >> log.txt
			dialog --msgbox "OK" 10 20
			programEnd
		else
			echo "error(-d)" >> log.txt
			dialog --msgbox "failed to create container" 10 40
			return
		fi
	else
		echo "-it option" >> log.txt
		dialog --msgbox "-it option : please enter command self" 10 50
		programEnd "command : $createCmd"
	fi
}

function showConfig {
        local showCmd
        local msgCmd

        echo "show config" >> log.txt
        logblock "show config"

	#image info set
        local imageShow
        if [ "$image" != "" ]
        then
                imageShow="image : $image"
        else
                imageShow="no image selected"
        fi

	#network info set
        local networkShow
        if [ $(getField $network 1) == "n" ]
        then
                if [ $(getField $network 3) != "null" ]
                then
                        networkShow="network : $(getField $network 2)($(getField $network 3))"
                else
                        networkShow="network : $(getField $network 2)"
                fi
        elif [ $(getField $network 1) == "p" ]
        then
                networkShow="network : port mapping($(getField $network 2))"
        else
                networkShow="no network selected"
        fi

	#volume info set
        local volumeShow
        if [ "$volume" != "" ]
        then
                volumeShow="volume : $volume"
        else
                volumeShow="no volume selected"
        fi

	#name info set
        local nameShow
        if [ $(getField $name 1) != "" ]
        then
		nameShow="name : $(getField $name 1)"
        else
		nameShow="no name set"
        fi

	#hostname info set
        local hostnameShow
        if [ $(getField $name 2) != "" ]
        then
                hostnameShow="hostname : $(getField $name 2)"
        else
                hostnameShow="no hostname set"
        fi

	#link info set
        local linkShow
        if [ "$link" != "" ]
        then
                linkShow="link : $link"
        else
                linkShow="no link set"
        fi

	#internet info set
        local internetShow
        if $cInternet
        then
                internetShow="internet : connected"
        else
                internetShow="internet : not connected"
        fi

	#make window
        msgCmd="$imageShow\n$networkShow\n$volumeShow\n$nameShow\n$hostnameShow\n$linkShow\n\n$internetShow"
        showCmd="dialog^--msgbox^$msgCmd^20^50"

	#window
	tmpIFS=$IFS
	IFS="^"
        $showCmd 2> $tmptxt
	IFS=$tmpIFS

        echo "OK" >> log.txt
}

function checkInternet {
        echo "internet check" >> log.txt
        logblock "internet"

        ping -c 3 www.google.com > /dev/null 2>> error.txt
        if [ $? -eq 0 ]
        then
                echo "connected" >> log.txt
                cInternet=true
                dialog --msgbox "connected" 10 20
        else
                echo "not connected" >> log.txt
                cInternet=false
                dialog --msgbox "failed to connect internet" 10 40
        fi
}

function exitMenu {
        echo "exit" >> log.txt
        logblock "exit menu(Exit?)"

        dialog --yesno "exit?" 10 20
        if [ $? -eq 0 ]
        then
                echo "yes" >> log.txt
                programEnd
        else
                echo "no" >> log.txt
        fi
}

function mainmenu {
	logblock "mainmenu"

	#make menu
	dialog --menu "mainmenu" 30 50 20 \
                1 "select image (Required)" 2 "select network" 3 "select volume" 4 "set name" 5 "set link" \
		6 "create" 7 "show config" 8 "check internet" 9 "exit" 2> $tmptxt
	
	#menu
	local menuIdx=$(cat $tmptxt)
	case $menuIdx in
	1)
		imageMenu ;;
	2)
		networkMenu;;	
	3)
		volumeMenu;;
	4)
		nameMenu ;;
	5)
		linkMenu ;;
	6)
		createMenu;;
	7)
		showConfig ;;
	8)
		checkInternet ;;
	9 | "")
		exitMenu ;;
	esac
}

#----------Main start-----------------------------
prework

while true
do
	mainmenu
done
