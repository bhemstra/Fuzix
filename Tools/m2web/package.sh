#!/bin/sh
#
#	package.sh: make m2web.zip, the emulator ready to put on a web site:
#	the page, both hard disks (Fuzix and LS-DOS), LEESMIJ.txt and the
#	licence notes. Needs Images/trs80m2/hard2-0.hdv and lsdos2-0.hdv
#	(make TARGET=trs80m2 diskimage, Tools/lsdos2/build.py).
#
set -e
cd "$(dirname "$0")"
IMG=../../Images/trs80m2
./mkdisk.sh $IMG/hard2-0.hdv hard2-0 >/dev/null
./mkdisk.sh $IMG/lsdos2-0.hdv lsdos2-0 >/dev/null
D=$(mktemp -d)
mkdir $D/m2web
cp index.html m2.js z80.js disks.json hard2-0.hdv.gz lsdos2-0.hdv.gz $D/m2web/
cat > $D/m2web/LEESMIJ.txt <<'TXT'
TRS-80 Model II-emulator voor een website
=========================================

Inhoud
  index.html        de pagina
  m2.js, z80.js     de emulator
  disks.json        de harde schijven in het keuzemenu
  hard2-0.hdv.gz    Fuzix
  lsdos2-0.hdv.gz   LS-DOS 6.3.1
  LICENTIES.txt     licenties en bronnen

Op de website zetten
  Zet de map m2web in zijn geheel op de server, bijvoorbeeld als /m2/
  (per FTP; laat RapidWeaver de bestanden niet beheren). De pagina moet
  via http(s) worden geopend; dubbelklikken op index.html werkt niet.

  Openen:              https://jouwsite/m2/
  Met LS-DOS starten:  https://jouwsite/m2/?disk=lsdos2-0.hdv.gz
  Zonder titel/uitleg: https://jouwsite/m2/?embed=1

In RapidWeaver
  Een HTML Code-element, HTML-stack of HTML Code-pagina met:

  <iframe src="/m2/index.html?embed=1" title="TRS-80 Model II"
          style="width:100%; height:900px; border:0"></iframe>

  Voeg &disk=lsdos2-0.hdv.gz toe om met LS-DOS te starten.

Meer schijven
  Zet het .hdv- of .hdv.gz-bestand in de map en voeg een regel toe aan
  disks.json, bijvoorbeeld:
    { "name": "Spellen", "file": "spellen.hdv.gz" }
  Alleen Model II-images die vanaf de harde schijf kunnen opstarten werken.
  Bezoekers kunnen ook een eigen .hdv kiezen ("Eigen image"); dat blijft
  in hun browser. Wijzigingen op de schijf worden niet bewaard.

Lokaal uitproberen
  In deze map: python3 -m http.server 8000
  en open http://localhost:8000/

Bij Fuzix: inloggen als root. Bij LS-DOS: datum en tijd invullen.
TXT
cat > $D/m2web/LICENTIES.txt <<'TXT'
Fuzix (hard2-0.hdv.gz) staat onder de GPL versie 2. De broncode:
https://github.com/bhemstra/Fuzix (en https://github.com/EtchedPixels/FUZIX).

De emulator (index.html, m2.js) komt uit Tools/m2web van dezelfde repository.
z80.js bevat z80-emulator en z80-base van Lawrence Kesteloot, MIT-licentie
(zie de kop van z80.js), https://github.com/lkesteloot/trs80.

LS-DOS 6.3.1 (lsdos2-0.hdv.gz), gebouwd met Tools/lsdos2 uit de bronnen van
https://github.com/GmEsoft/TRS80_M2_LSDOS631N. De toestemming om het te
verspreiden vraagt dat deze tekst erbij blijft:

TXT
sed -n "/^NOTICE = '''/,/^'''/p" ../lsdos2/build.py | sed "1s/^NOTICE = '''//; \$d" >> $D/m2web/LICENTIES.txt
rm -f m2web.zip
(cd $D && zip -qr9 - m2web) > m2web.zip
rm -rf $D
ls -l m2web.zip
