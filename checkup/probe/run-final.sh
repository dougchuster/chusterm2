#!/bin/sh
export QA_BASE_URL=http://127.0.0.1:3010 QA_FIXTURE_PASSWORD='ChkUp!2026-09-18-qa-local' MSYS_NO_PATHCONV=1
mkdir -p results/final
node sweep.mjs --persona admin --width 1440 --axe --shots && cp results/admin-1440.json results/final/
node sweep.mjs --persona admin --width 360 && cp results/admin-360.json results/final/
node sweep.mjs --persona operator --width 1440 && cp results/operator-1440.json results/final/
node sweep.mjs --persona anon --width 1440 && cp results/anon-1440.json results/final/
node auth.mjs > results/final/auth.txt 2>&1
node crm-crud.mjs > results/final/crm-crud.txt 2>&1
node core-crud.mjs > results/final/core-crud.txt 2>&1
node tenant.mjs > results/final/tenant.txt 2>&1
node superadmin.mjs > results/final/superadmin.txt 2>&1
node ui-crm.mjs > results/final/ui-crm.txt 2>&1
echo FINAL_DONE
