#!/bin/bash

###########################
### Certificate Setting ###
###########################

Country="IL"
Province_Name="PolaviHome"
Organization_Name="Smart Home"
Organizational_Unit_Name="Smart Home CA"
Common_Name="*.nav"
Email_Address="lavif6@gmail.com"

TLD="nav"

###########################
### Files & Permissions ###
###########################

#Files extension
CSR_File_Extension="csr"
Crt_File_Extension="crt"
Conf_File_Extension="openssl.cnf"
Priv_Key_File_Extension="privkey"

#Files Ownership
Def_Group="root"
Def_Own="ca"

CSR_File_Own="${Def_Own}:${Def_Group}"
Crt_File_Own="${Def_Own}:${Def_Group}"
Conf_File_Own="${Def_Own}:${Def_Group}"
Priv_File_Own="${Def_Own}:${Def_Group}"

#Files Permissions
Def_Perm="660"

CSR_File_Perm="${Def_Perm}"
Crt_File_Perm="${Def_Perm}"
Conf_File_Perm="${Def_Perm}"
Priv_File_Perm="400"

###########################
###   Folders& Path    ###
###########################

#Directorys Path
Main_Dir="/home/ca"
Crt_Dir="${Main_Dir}/certs"
Priv_Key_Dir="${Main_Dir}/private"
CSR_Dir="${Main_Dir}/csr"
Conf_Files_Dir="${Main_Dir}/opensslconf"

#Openssl conf Defaulte
Openssl_Conf_Def="${Conf_Files_Dir}/openssl.cnf"

#CA Password
CA_Pass_Path="pass home/ca/caprivkey"

###########################
###   Script Settings   ###
###########################

#Defaulte
Key_Bit_Def=2048

#Defaulte answer
Encrypt_Priv_Key_Def="no"
Wizard_Action_Def="create"
Issued_To_Def="test"
Cert_Type_Def="server"
Delete_Policy_Def="yes"
More_Alt_Name_Def="no"

#Color Settings
CLI_Def_Color="\e[39m"

Title_Color="\e[34m"
Text_Color="${CLI_Def_Color}"
Error_Color="\e[31m"
Question_Color="${CLI_Def_Color}"
Answer_Color="\e[93m"
Step_Color="\e[93m"

###########################
###  Publics Variable   ###
###########################

program_step_index=1

###########################
###    Main Function    ###
###########################

function main
{
	printText "\nWelcome to the "
	printInColor "Certificate Creation Wizard" ${Title_Color}
	printText ". (By Lavi Friedman)\n\n"

	Question "Issued to" ${Issued_To_Def} Issued_To
	Question "Is the action you want to do is create or delete a certificate" ${Wizard_Action_Def} wizard_action

	Issued_To="${Issued_To}.${TLD}"

	if [ ${wizard_action} == "create" ]
	then
		createCrt ${Issued_To}

	elif [ ${wizard_action} == "delete" ]
	then
		deleteCrt ${Issued_To}
	else
		printError "Wizard_Action"
	fi

	printText "\nCertificate Creation Wizard end.\n\n"
}

###########################
###  Public Functions   ###
###########################

function createCrt
{
	Question "What kind of certification do you want to create" ${Cert_Type_Def} Cert_Type
	Question "Encrypt private key required" ${Encrypt_Priv_Key_Def} Encrypt_Priv_Key
	printText "\nStart the prosses:\n"

	genPrivateKey ${Issued_To} ${Encrypt_Priv_Key} ${Key_Bit_Def}

	makeOpensslConfFile ${Issued_To} ${Cert_Type}

	makeCSR ${Issued_To}

	singCSR ${Issued_To} ${Cert_Type}
}


# $1 - Issued_To
function deleteCrt
{
	Question "Are you sure you want to delete $1" ${Delete_Policy_Def} Delete_Policy

	printText "\nThe certificate $1 was "
	
	if [ ${Delete_Policy} == "yes" ]
	then
		find . -name "$1*" -type f -delete
		Delete_Status="Delete"
	else
		Delete_Status="Not Delete"
	fi

	printInColor ${Delete_Status} $Title_Color
	printText ".\n"
}


# $1 - Issued_To
# $2 - Is_Key_Pass
# $3 - Key_Bit_Def
function  genPrivateKey
{
	printStep "Generate private key"
	Priv_File_Path="${Priv_Key_Dir}/$1.${Priv_Key_File_Extension}"

	if [ $2 == "yes" ]
	then
		openssl genrsa -aes256			\
			-out ${Priv_File_Path} $3

	elif [ $2 == "no" ]
	then
		openssl genrsa					\
			-out ${Priv_File_Path} $3

	else
		printError "Wizard_Action: |$2|"
	fi

	fileOwnAndPerm ${Priv_File_Own} ${Priv_File_Perm} ${Priv_File_Path}
}


# $1 - Issued_To
# $2 - Cert_Type
function makeOpensslConfFile
{
	printStep "Make openssl configuration file"
	Conf_File_Path="${Conf_Files_Dir}/$1.${Conf_File_Extension}"
	cp ${Openssl_Conf_Def} ${Conf_File_Path}

	fileOwnAndPerm ${Conf_File_Own} ${Conf_File_Perm} ${Conf_File_Path}

	Alt_Name_Index=1
	addAltName $1 ${Alt_Name_Index} $1

	if [ $2 == "server" ]
	then
		Question "Do you want to add another Alternative Name" ${More_Alt_Name_Def} More_Alt_Name

		while [ ${More_Alt_Name} == "yes" ]
		do
			printText "Alt name number ${Alt_Name_Index}: "
			read Alt_Name
			addAltName $1 ${Alt_Name_Index} ${Alt_Name}
			Question "\nDo you want to add another Alternative Name" ${More_Alt_Name_Def} More_Alt_Name
		done

	elif [ $2 == "client" ]
	then
		printText "\n  Alt name is $1\n"
	else
		printError "  Cert_Type: |$2|"
	fi
}


# $1 - Issued_To
function makeCSR
{
	printStep "Make certificate signing request file"

	CSR_File_Path="${CSR_Dir}/$1.${CSR_File_Extension}"

	openssl req -new -sha256 		\
		-config ${Conf_File_Path} 	\
		-key ${Priv_File_Path}		\
		-out ${CSR_File_Path}		\
		-subj "/C=${Country}/ST=${Province_Name}/O=${Organization_Name}/OU=${Organizational_Unit_Name}/CN=$1/emailAddress=${Email_Address}"

	fileOwnAndPerm ${CSR_File_Own} ${CSR_File_Perm} ${CSR_File_Path}
	
	#openssl req -text -noout -verify -in ${CSR_File_Path}
}


# $1 - Issued_To
function singCSR
{
	printStep "Sign the certificate"

	CA_Pass=$(${CA_Pass_Path})
	Crt_File_Path="${Crt_Dir}/$1.${Crt_File_Extension}"

	printf "\n${Crt_File_Path}\n"
	openssl ca -md sha256 -batch	\
		-extensions ${Cert_Type}	\
		-config ${Conf_File_Path}	\
		-in ${CSR_File_Path}		\
		-out ${Crt_File_Path}		\
		-key ${CA_Pass}

	fileOwnAndPerm ${Crt_File_Own} ${Crt_File_Perm} ${Crt_File_Path}

	#openssl x509 -noout -text -in ${Crt_File_Path}
}

###########################
###  Private Functions  ###
###########################

# $2 - Own and Group
# $3 - Permissions
# $1 - File name
function fileOwnAndPerm
{
	chown $1 $3
	chmod $2 $3
}


# $1 - Issued_To
# $2 - Alt_Name_Index
# $3 - Alt_Name
function addAltName
{
	echo "DNS.$2 = $3 " >> ${Conf_File_Path}
	Alt_Name_Index=$((${Alt_Name_Index} + 1))
}


# $1 - Text
# $2 - Color
function printInColor
{
	printf "$2$1\e[39m"
	# "\e[39m$1$\e[39m"
}

# $1 - Text
# $2 - Defaulte value
# $3 - Ptr to return
function Question
{
	local -n answer=$3
	printText "$1 ["
	printInColor $2 ${Answer_Color}
	printText "]: "
		read answer
		if [ -z ${answer} ]
		then
			answer=$2
		fi
}


# $1 - Text
function printText
{
	printInColor "$1" "${Text_Color}"
}


# $1 - Step text
function printStep
{
	printInColor "\n  -- ${program_step_index}. $1\n" ${Step_Color}
	program_step_index=$((program_step_index+1))
}


# $1 - Error text
function printError
{
	printInColor "  Error:${program_step_index}: $1.\n" ${Error_Color}
	exit
}

###########################
###    Initial code     ###
###########################

#Exit if command fails
set -e

#Run the main func
main
