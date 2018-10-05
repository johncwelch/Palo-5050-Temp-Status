#!/bin/bash

#this gets the name, rpm, and status of all the fans in the palo 5050s

#clear the getopts OPTIND
OPTIND=1

#set up TESTVAR
TESTVAR=""

#make newline a variable to make life easier

NEWLINE='\n'

#set up array vars
declare -a SNMPTABLETEMP #raw snmptable return
declare -a TEMPSTATUSTEMPS #for individual temp values
declare -a TEMPSTATUS #for actual fan status, ok or not okay
declare -a SNMPTABLENAME #snmptable return for name
declare -a TEMPSTATUSNAME #for indvidual names
declare -a TEMPSTATUSRESULTS #use an array for this, makes for neater output
declare -a TEMPPERFDATANAMES #this is where we create perfdata-appropriate names

#set up array start for TEMPSTATUSTEMPS
declare -i tempsindex
tempsindex=0

#set up array start for TEMPSTATUSNAME
declare -i nameindex
nameindex=0

#parse options
while getopts "H:c:h:" option
     do
          case "${option}" in

          H) HOSTNAME=$OPTARG;;

          c) COMMUNITY=$OPTARG;;
          
          h) echo "Usage - palofanstatus.sh -H <hostname> -c <SNMP v2c Community string> BOTH flags are required" >&2
          exit 1
          ;;

          \?) echo "Invalid option: -$OPTARG Usage - palofanstatus.sh -H <hostname> -c <SNMP v2c Community string> BOTH flags are required" >&2
          exit 1
          ;;

          ?) echo "Invalid option: -$OPTARG Usage - palofanstatus.sh -H <hostname> -c <SNMP v2c Community string> BOTH flags are required" >&2
          exit 1
          ;;

          :) echo "Option -$OPTARG requires a parameter. Usage - palofanstatus.sh -H <hostname> -c <SNMP v2c Community string> BOTH flags are required" >&2
          exit 1
          ;;

          *) echo "Invalid option: -$OPTARG Usage - palofanstatus.sh -H <hostname> -c <SNMP v2c Community string> BOTH flags are required" >&2
          exit 1
          ;;

          esac
     done

#set the input field separator to newline, this avoids problems with spaces in the snmptable return
IFS=$'\n'

#get the snmptable for temps with no headers and comma-delimited
SNMPTABLETEMP=($(snmptable -v 2c -c $COMMUNITY -m ALL -CH -Cf , $HOSTNAME .1.3.6.1.2.1.99.1.1))

#get snmptable for fan names, no headers, comma delimited
SNMPTABLENAME=($(snmptable -v 2c -c $COMMUNITY -m ALL -CH -Cf , $HOSTNAME .1.3.6.1.2.1.47.1.1.1))

#iterate through SNMPTABLENAME, grab the name of each temp sensor
for i in "${!SNMPTABLENAME[@]}"; do
     TESTVAR="$(echo ${SNMPTABLENAME[i]}|cut -d',' -f1)"
     if [[ ${TESTVAR} != Temperature* ]]
     then
          continue
     else
          TEMPSTATUSNAME[nameindex]=$TESTVAR
          ((nameindex++))
     fi
done

#iterate through SNMPTABLETEMP. Assign the first column using commas as field separators to TESTVAR
#if TESTVAR is "celsius", then assign the 4th column to TEMPSTATUSTEMPS and the 5th column to TEMPSTATUS
#note that TEMPSTATUSTEMPS uses "index" as it's index variable, hence the increment in the if statement
for i in "${!SNMPTABLETEMP[@]}"; do
     TESTVAR="$(echo ${SNMPTABLETEMP[i]}|cut -d',' -f1)"       
     if [ $TESTVAR == "celsius" ]
     then
          TEMPSTATUSTEMPS[tempsindex]="$(echo ${SNMPTABLETEMP[i]}|cut -d',' -f4)"
          TEMPSTATUS[tempsindex]="$(echo ${SNMPTABLETEMP[i]}|cut -d',' -f5)"
          ((tempsindex++))
     fi
done

#build TEMPSTATUSRESULTS
for i in "${!TEMPSTATUSTEMPS[@]}"; do
      TEMPSTATUSRESULTS[i]="${TEMPSTATUSNAME[i]}: ${TEMPSTATUSTEMPS[i]}, ${TEMPSTATUS[i]};"
done

#build the data output string for nagios
TEMPSTATUSOUTPUT="" #initialize this

#and here's our output, built the nagios way
for i in "${TEMPSTATUSRESULTS[@]}"; do
     TEMPSTATUSOUTPUT+=$i"\n"
done

#remove trailing \n by yanking last two characters. 
TEMPSTATUSOUTPUT=${TEMPSTATUSOUTPUT%??}

#glom pipe char onto end of FANSTATUSOUTPUT, needed to separate human output from service perf data
TEMPSTATUSOUTPUT+="|"

tempresultsindex=0 #this is a counter for shoving our perfdata names into the perfdata string

##build perfdata string

#build the names for perfdata labels in the perfdata string
for i in "${!TEMPSTATUSNAME[@]}"; do
     TEMPPERFDATANAMES[i]="$(echo ${TEMPSTATUSNAME[i]}|cut -d' ' -f1,4 --output-delimiter=' ')"
done

TEMPSTATUSPERFDATA=""
for i in "${TEMPSTATUSTEMPS[@]}"; do
     TEMPSTATUSPERFDATA+="'${TEMPPERFDATANAMES[tempresultsindex]}'="$i" "
    ((tempresultsindex++))
done

#trim trailing space from TEMPSTATUSPERFDATA
TEMPSTATUSPERFDATA=${TEMPSTATUSPERFDATA%?}

#build final output string
TEMPSTATUSOUTPUT+=$TEMPSTATUSPERFDATA

#output the fan data with perfdata
echo -e $TEMPSTATUSOUTPUT

#we're ALWAYS FINE, even when we aren't. One day, I'll get clever here. Don't hold your breath.
exit 0