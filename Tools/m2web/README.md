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
| `mkdisk.sh`   | makes `hard2-0.hdv.gz.b64.txt`, the disk the page loads |
| `test.mjs`    | boots the image under Node and logs in, as a quick check |

The NMI is delivered by `m2.js` itself rather than by the Z80 library,
because the library clears IFF2 on an NMI while a real Z80 copies IFF1
into it, and the Fuzix clock handler depends on that.

## Use

```
make TARGET=trs80m2 diskimage      # in the top directory, if not done
Tools/m2web/mkdisk.sh
cd Tools/m2web && python3 -m http.server 8000
```

Then open http://localhost:8000/. Disk writes stay in memory until the
page is reloaded.

```
node Tools/m2web/test.mjs          # boots, logs in, runs ls and tbasic
```
