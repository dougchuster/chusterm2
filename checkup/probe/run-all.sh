#!/bin/sh
set -x
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona admin --width 1440 --shots --axe
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona admin --width 360 --shots
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona admin --width 768 --shots
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona operator --width 1440
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona seller --width 1440
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona manager --width 1440
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona knowledge_manager --width 1440
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona admin_b --width 1440
QA_BASE_URL=http://127.0.0.1:3010 node sweep.mjs --persona anon --width 1440
echo ALL_DONE
