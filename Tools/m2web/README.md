# m2web: the Model II in a browser

A TRS-80 Model II emulator that runs in a web page and boots Fuzix from
the hard disk image. It is a JavaScript port of `Tools/m2sim`: 32K fixed
page 0, pages 1-15 at 0x8000 (port 0xFF), video RAM at 0xF800, keyboard,
the 30Hz real time clock NMI and the WD1010 hard disk.

| File          | Contents                                                |
|---------------|---------------------------------------------------------|
| `index.html`  | the page: screen, keyboard, speed and example commands  |
| `m2.js`       | the Model II hardware                                   |
| `z80.js`      | z80-emulator 2.3.0 and z80-base 2.0.1 by Lawrence Kesteloot (MIT), bundled with esbuild |
| `mkdisk.sh`   | makes a disk file (`.hdv.gz`, or `.hdv.gz.b64.txt` with `-b`) from an image |
| `disks.json`  | the disks the page offers                                |
| `test.mjs`    | boots the image under Node and logs in, as a quick check |
| `m4boot.mjs`  | runs the Model 4 hard disk boot sector against `hard4p-0.hdv` as the 4P ROM would |

The NMI is delivered by `m2.js` itself rather than by the Z80 library,
because the library clears IFF2 on an NMI while a real Z80 copies IFF1
into it, and the Fuzix clock handler depends on that.

## Use

```
make TARGET=trs80m2 diskimage      # in the top directory, if not done
Tools/m2web/mkdisk.sh              # writes hard2-0.hdv.gz
cd Tools/m2web && python3 -m http.server 8000
```

Then open http://localhost:8000/. Disk writes stay in memory until the
page is reloaded.

```
node Tools/m2web/test.mjs          # boots, logs in, runs ls and tbasic
```

## On a web site

The page needs nothing but a static web server. Copy these files into one
folder on the site, for example `/m2/`:

```
index.html  m2.js  z80.js  disks.json  hard2-0.hdv.gz  (and the other disks)
```

It must be opened over http(s), not as a file. `.js` files must be served
as JavaScript (any normal server does that). If the server sends `.gz` files
with `Content-Encoding: gzip`, the browser unpacks them and the page takes
the plain image just as well.

### More than one hard disk

Make a disk file for each image and list it in `disks.json`; the page shows
them in the "Harde schijf" menu and remembers the last choice:

```
Tools/m2web/mkdisk.sh ~/images/games.hdv games   # writes games.hdv.gz
```

```json
[
  { "name": "Fuzix (Model II)", "file": "hard2-0.hdv.gz" },
  { "name": "Spellen", "file": "games.hdv.gz" }
]
```

A disk must be a Model II `.hdv` (header byte 8 has the Model II flag 0x02,
32 sectors of 512 bytes per track) whose cylinder 0 holds a boot program
the hard disk boot ROM accepts (a sector starting with `/* END BOOT */`).
Visitors can also start their own image with "Eigen image"; it stays in
their browser. Disk writes are never saved.

Address options: `?disk=games.hdv.gz` starts with that disk (by file or
name), `?embed=1` leaves out the title and the explanation.

### RapidWeaver

The simplest way is to keep the emulator as its own folder on the server,
next to the site (upload it by FTP, so RapidWeaver does not touch the
files), and show it in a RapidWeaver page with an iframe in an HTML code
element, an HTML stack or an "HTML Code" page:

```html
<iframe src="/m2/index.html?embed=1" title="TRS-80 Model II"
        style="width:100%; height:900px; border:0"></iframe>
```

Different RapidWeaver pages can each start a different disk with
`?embed=1&disk=...`.
