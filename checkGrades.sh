#! /bin/bash
# Checking grades for the grade information system of the university Heilbronn. Written bei Maximilian Westers. For more information see https://github.com/Findus1994/GradesChecker/wiki 

# Edit these information with your credentials and your accesstoken from PushBullet
username="username"
password="password"
accessToken="accessToken"

# For normal you don't have to change anything here. If the script producing an error you can check if all the urls and field names are still valid.
userfieldname="asdf"
passfieldname="fdsa"
loginformactionsite="https://stud.zv.hs-heilbronn.de/qisstudent/rds?state=user&type=1&category=auth.login&startpage=portal.vm&breadCrumbSource=portal"
asiextractsite="https://stud.zv.hs-heilbronn.de/qisstudent/rds?state=change&type=1&moduleParameter=studyPOSMenu&nextdir=change&next=menu.vm&subdir=applications&xml=menu&purge=y&navigationPosition=functions%2CstudyPOSMenu&breadcrumb=studyPOSMenu&topitem=functions&subitem=studyPOSMenu"
gradessitebegin="https://stud.zv.hs-heilbronn.de/qisstudent/rds?state=notenspiegelStudent&next=list.vm&nextdir=qispos/notenspiegel/student&createInfos=Y&struct=auswahlBaum&nodeID=auswahlBaum%7Cabschluss%3Aabschl%3D88%2Cstgnr%3D1&expand=0&asi="
gradessiteend='#auswahlBaum%7Cabschluss%3Aabschl%3D88%2Cstgnr%3D1'
logoutsite="https://stud.zv.hs-heilbronn.de/qisstudent/rds?state=user&type=4&re=last&category=auth.logout&breadCrumbSource=&topitem=functions"
cookieinformationfile=".cookies.txt"
gradesFile="${HOME}/checkGradesMax/"$(date "+%Y.%m.%d-%H.%M.%S").xml
tableFile=.rohTable.html
header="Access-Token: $accessToken"
inital=true
author="Maximilian Westers (mwesters@stud.hs-heilbronn.de)"
version="2.0"

# If you want an other MOTD, feel free to change this one or change the path!
motdfile="./MotD.txt"

# Starting Program: Clearing terminal, showing MotD and other information
clear
echo -e "\n\n"
echo $(date "+%Y.%m.%d-%H.%M.%S")
echo ""
if [ -f "$motdfile" ]
then
  cat "$motdfile"
fi
echo -e "\nAuthor: $author\nVersion: $version\n"

# Checking for an older file to decide either producing an initial download or compare the files
olderFile=$(find "${HOME}/checkGradesMax/" -name '*xml' -print | head -n 1)
if [[ -z "$olderFile" ]]
then
  echo "Keine Ältere Datei gefunden! Initialer Download wird durchgeführt!"
else
  echo "Alte Datei gefunden. Vergleich wird gestartet!"
  initial=false
fi
echo ""
echo "-------------------Daten hohlen-------------------"
#Login (Saving the JSESSION)
echo -n "Login wird durchgeführt..."
wget --save-cookies $cookieinformationfile --keep-session-cookies --delete-after \
     --post-data "$userfieldname=$username&$passfieldname=$password&submit=Login" \
     "$loginformactionsite" > /dev/null 2>&1
echo "[DONE]"

# Gathering the ASI informationen
echo -n "ASI wird extrahiert..."
wget --load-cookies $cookieinformationfile \
     --local-encoding=utf-8 \
     -O .test.html \
     "$asiextractsite" \
     > /dev/null 2>&1

if [ -f .test.html ]
then
  if [ \! -s .test.html ]
  then
    echo -e "\nFehler! .test.html ist leer! Beende Skript!"
    rm .test.html
    exit
  fi
else
  echo -e "\nFehler! .test.html existiert nicht! Beende Skript!"
  exit
fi

cat .test.html | grep "asi=" -m 1 | awk -F"asi=" '{print $2}' | awk -F"\"" '{print $1}' > /dev/null 2>&1
asi=$(cat .test.html | grep "asi=" -m 1 | awk -F"asi=" '{print $2}' | awk -F"\"" '{print $1}')
rm .test.html
echo "[DONE] ($asi)"

# Gathering grades
echo -n "Lade Noten..."
gradessite="$gradessitebegin$asi$gradessiteend"
wget --load-cookies $cookieinformationfile --local-encoding=utf-8 -O .Grades.html "$gradessite" > /dev/null 2>&1
echo "[DONE]"

if [ -f .Grades.html ]
then
  if [ \! -s .Grades.html ]
  then
    echo -e "\nFehler....Beende Skript!"
    rm .Grades.html
    exit
  fi
else
  echo -e "\nFehler... Beende Skript!"
  exit
fi

# Logout
echo -n "Session wird invalidiert..."
wget --load-cookies $cookieinformationfile --local-encoding=utf-8 --delete-after "$logoutsite" > /dev/null 2>&1

#Deleting cookies file
rm $cookieinformationfile
echo "[DONE]"
echo ""
echo "-------------------Daten Formatieren------------------"

# Getting position of start and end of the gradestable
echo -n "Extrahieren der Daten in XML-File..."
anfangnormtabelle=$(egrep -n "<table border=\"0\">" .Grades.html | cut -d":" -f1)
endenormtabelle=$(cat .Grades.html  | egrep -n "</table>" | sed -ne 2p | cut -d":" -f1)

# Creating temporary file to work with
sed -ne "$anfangnormtabelle,${endenormtabelle}p" .Grades.html > .CompleteTable.html

# Cleaning up
rm .Grades.html

# Extracting raw table
anfangrohtabelle=$(cat .CompleteTable.html  | egrep -n "<tr>" | sed -ne 3p | cut -d":" -f1)
echo "<table>" > $tableFile && sed -ne "$anfangrohtabelle,5000p" .CompleteTable.html | sed 's/&nbsp;//g' | sed -e 's/^\s*//' -e '/^$/d' >> $tableFile
rm .CompleteTable.html

# Creating the XML-file
positionExamNr=0
positionGrade=1
positionName=9

zeilenAnfang=$(cat $tableFile | grep -n "<tr>" | cut -d":" -f1 | sed ':a;N;$!ba;s/\n/;/g') 
zeilenEnde=$(cat $tableFile | grep -n "</tr>" | cut -d":" -f1 | sed ':a;N;$!ba;s/\n/;/g')
IFS=";" read -a arrayAnfangsZeilen <<< "$zeilenAnfang"
IFS=";" read -a arrayEndeZeilen <<< "$zeilenEnde"
groesseArray=$(cat $tableFile | grep -c "<tr>")
echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" > $gradesFile
echo "<grades>" >> $gradesFile

i=0
add=1
while [ "$i" != "$groesseArray" ]
do
echo "<exam>" >> $gradesFile
anfangsposition=${arrayAnfangsZeilen[$i]}
endeposition=${arrayEndeZeilen[$i]}
teil=$(sed -n $anfangsposition,${endeposition}p $tableFile)
spaltenAnfang=$(sed -n $anfangsposition,${endeposition}p $tableFile | grep -n "<td" | cut -d":" -f1 | sed ':a;N;$!ba;s/\n/;/g')
IFS=";" read -a arrayAnfangSpalten <<< "$spaltenAnfang"
groesseArraySpalten=$(sed -n $anfangsposition,${endeposition}p $tableFile | grep -c "<td")

j=0
while [ "$j" != "$groesseArraySpalten" ]
do

if [ "$j" = "$positionExamNr" ]
then
  echo "<number>" >> $gradesFile
  sed -n $anfangsposition,${endeposition}p $tableFile | sed -n $((${arrayAnfangSpalten[$j]} + $add))p >> $gradesFile
  echo "</number>" >> $gradesFile
elif [ "$j" = "$positionGrade" ]
then
  echo "<grade>" >> $gradesFile
  sed -n $anfangsposition,${endeposition}p $tableFile | sed -n $((${arrayAnfangSpalten[$j]} + $add))p >> $gradesFile
  echo "</grade>" >> $gradesFile
elif [ "$j" = "$positionName" ]
then
  echo "<name>" >> $gradesFile
  sed -n $anfangsposition,${endeposition}p $tableFile | sed -n $((${arrayAnfangSpalten[$j]} + $add))p >> $gradesFile
  echo "</name>" >> $gradesFile
fi
j=$(($j + $add))
done
echo "</exam>" >> $gradesFile
i=$(($i + $add))
done 


echo "</grades>" >> $gradesFile
rm $tableFile

echo "[DONE]"

# Comparing the xml files to check if new grades exists (just if it isn't the initial download)
if ! $initial
then
  echo "----------------Vergleich Dateien-------------"
  echo -n "Suche nach neuen Noten..."
  countNew=$(awk 'BEGIN{
      totalelem=0
    }
    /<exam>/{
      m = split($0,a,"<exam>")
      totalelem+=m-1
    }
    END{
      print totalelem
    }
  ' $gradesFile)
  echo "Anzahl: $countNew"

  countOld=$(awk 'BEGIN{
      totalelem=0
    }
    /<exam>/{
      m = split($0,a,"<exam>")
      totalelem+=m-1
    }
    END{
      print totalelem
    }
  ' $olderFile)

# Sending PushBullet Notification if new grade was detected
  if [ $countOld -lt $countNew ]
  then
    echo "Neue Note gefunden. Sende Info an über PushBullet!"
    curl --header "$header" -X POST https://api.pushbullet.com/v2/pushes --header "Content-Type: application/json" --data-binary "{\"type\": \"note\", \"title\": \"Neue Note!\", \"body\": \"Es wurde eine neue Note eingetragen!\"}" > /dev/null
  else
    #Test des Systems --> Notification egal wie ergebnis ausfällt!
    #curl --header "$header" -X POST https://api.pushbullet.com/v2/pushes --header "Content-Type: application/json" --data-binary "{\"type\": \"note\", \"title\": \"Nope!\", \"body\": \"Das Skript wurde ausgeführt aber keine neue Note gefunden!\"}" > /dev/null
    echo "Keine Neue Note gefunden"
fi

# Cleaning up
  echo "-------------------Aufräumen------------------"
  echo -n "Der Ordner wird aufgeräumt..."
  rm $olderFile
  echo "[DONE]"

# Sending information about the initial download
else
  echo "Initialer Download abgeschlossen!"
  curl --header "$header" -X POST https://api.pushbullet.com/v2/pushes --header "Content-Type: application/json" --data-binary "{\"type\": \"note\", \"title\": \"CheckGrades ist bereit!\", \"body\": \"Initialer Download wurde abgeschlossen! Das Script ist nun bereit Noten zu überprüfen.\"}" > /dev/null
fi
