#Requires -Version 5.1
<#
.SYNOPSIS
    Rollback: mod-gear-ascension Phase 3 -> revert live acore_world to pre-deploy state.
    Package: 2026-06-21_0900-gear-ascension-phase3

.DESCRIPTION
    Human-run script. Two rollback options (script prompts for choice):

    Option A — Surgical DELETE (preferred, fast ~30s):
      Removes only the Phase 3 rows using the same scoped DELETE statements as the SQL file.
      Does NOT touch Phase 1/2 data (300001-345833) or any other acore_world tables.
      No restore of snapshot needed. Safe even if snapshot was skipped.

    Option B — Full snapshot restore (slow, complete):
      Restores the full acore_world from pre-deploy-snapshot.sql.gz taken by apply.ps1.
      Use this if Option A fails or if data corruption is suspected beyond the Phase 3 range.
      WARNING: A full restore rewrites ALL of acore_world — including any concurrent writes
      (other tables) that happened between the snapshot and the rollback. Use Option B only
      when Option A cannot work.

    Volume Item.dbc rollback (optional, separate):
      The patched Item.dbc (56465 records) was deployed to the shared volume BEFORE this
      package was created. Rolling back the SQL does NOT require rolling back the DBC — the
      DBC entries for 345841-356762 are simply ignored by the server while those item_template
      rows are absent. Only revert the DBC if you suspect the DBC file itself is corrupted.
      DBC revert command is included at the end of this script (commented out, manual step).

    After rollback: restart ac-worldserver-v2 to reload item_template from DB.

.NOTES
    Agent permission policy: this script is USER-RUN, NOT agent-run.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$REPO_ROOT    = "D:\Projects\Wow\v2\azerothcore-wotlk-playerbots\azerothcore-wotlk"
$DB_CONTAINER = "ac-database-v2"
$WS_CONTAINER = "ac-worldserver-v2"
$DB_USER      = "root"
$DB_PASS      = if ($env:DOCKER_DB_ROOT_PASSWORD) { $env:DOCKER_DB_ROOT_PASSWORD } else { "password" }
$WORLD_DB     = "acore_world"

$PKG_DIR      = "$REPO_ROOT\.claude\agent-memory\live-deployer\packages\2026-06-21_0900-gear-ascension-phase3"
$SNAPSHOT_GZ  = "$PKG_DIR\pre-deploy-snapshot.sql.gz"

# Origin entry list for the 1093 Phase 3 bases (same list as in gear_ascension_extra.sql)
# Used by Option A surgical DELETE on item_upgrade_chain.
$ORIGIN_ENTRIES = "2300, 2302, 2303, 2307, 2308, 2309, 2310, 2311, 2312, 2314, 2315, 2316, 2317, 2568, 2569, 2570, 2572, 2576, 2577, 2578, 2579, 2580, 2582, 2583, 2584, 2585, 2587, 2844, 2845, 2847, 2848, 2849, 2850, 2851, 2852, 2853, 2854, 2857, 2864, 2865, 2866, 2867, 2868, 2869, 2870, 3469, 3471, 3472, 3473, 3480, 3481, 3482, 3483, 3484, 3485, 3487, 3488, 3489, 3490, 3491, 3492, 3719, 3835, 3836, 3837, 3840, 3841, 3842, 3843, 3844, 3845, 3846, 3847, 3848, 3849, 3850, 3852, 3853, 3854, 3855, 3856, 4237, 4239, 4242, 4243, 4244, 4246, 4247, 4248, 4249, 4250, 4251, 4252, 4253, 4254, 4255, 4256, 4257, 4258, 4259, 4260, 4262, 4264, 4307, 4308, 4309, 4310, 4311, 4312, 4313, 4314, 4315, 4316, 4317, 4318, 4319, 4320, 4321, 4322, 4323, 4324, 4325, 4326, 4327, 4328, 4329, 4330, 4331, 4332, 4333, 4334, 4335, 4336, 4343, 4344, 4362, 4368, 4369, 4372, 4373, 4379, 4381, 4383, 4385, 4393, 4396, 4397, 4455, 4456, 5540, 5541, 5542, 5739, 5766, 5770, 5780, 5781, 5782, 5783, 5957, 5958, 5961, 5962, 5963, 5964, 5965, 5966, 6040, 6214, 6219, 6238, 6239, 6240, 6241, 6242, 6243, 6263, 6264, 6350, 6384, 6385, 6466, 6467, 6468, 6709, 6730, 6731, 6733, 6786, 6787, 6795, 6796, 6836, 7026, 7027, 7046, 7047, 7048, 7049, 7050, 7051, 7052, 7053, 7054, 7055, 7056, 7057, 7058, 7059, 7060, 7061, 7062, 7063, 7064, 7065, 7166, 7189, 7276, 7277, 7280, 7281, 7282, 7283, 7284, 7285, 7348, 7349, 7352, 7358, 7359, 7373, 7374, 7375, 7377, 7378, 7386, 7387, 7390, 7391, 7506, 7913, 7914, 7915, 7916, 7917, 7918, 7919, 7920, 7921, 7922, 7924, 7925, 7926, 7927, 7928, 7929, 7930, 7931, 7932, 7933, 7934, 7935, 7936, 7937, 7938, 7939, 7941, 7942, 7943, 7944, 7945, 7946, 7947, 7954, 7955, 7956, 7957, 7958, 7959, 7960, 7961, 7963, 8174, 8175, 8176, 8185, 8187, 8189, 8191, 8192, 8193, 8195, 8197, 8198, 8200, 8201, 8202, 8203, 8204, 8205, 8206, 8207, 8208, 8209, 8216, 8345, 8346, 8347, 8348, 8349, 8367, 9366, 9998, 9999, 10008, 10009, 10010, 10011, 10018, 10019, 10020, 10021, 10023, 10024, 10025, 10027, 10028, 10029, 10030, 10031, 10032, 10033, 10034, 10035, 10036, 10038, 10039, 10040, 10041, 10042, 10044, 10045, 10046, 10047, 10048, 10052, 10053, 10054, 10055, 10056, 10421, 10423, 10499, 10500, 10501, 10502, 10503, 10506, 10508, 10510, 10518, 10542, 10543, 10545, 10576, 10577, 10585, 10587, 10588, 10645, 10716, 10720, 10721, 10723, 10724, 10725, 10726, 10727, 11287, 11288, 11289, 11290, 11604, 11605, 11606, 11607, 11608, 11811, 12259, 12260, 12405, 12406, 12408, 12409, 12410, 12414, 12415, 12416, 12417, 12418, 12419, 12420, 12610, 12611, 12612, 12613, 12614, 12618, 12619, 12620, 12624, 12625, 12628, 12632, 12633, 12636, 12764, 12769, 12772, 12773, 12774, 12775, 12776, 12777, 12779, 12781, 12782, 12783, 12784, 12790, 12792, 12794, 12795, 12796, 12797, 12798, 12802, 13856, 13857, 13858, 13860, 13863, 13864, 13865, 13866, 13867, 13868, 13869, 13870, 13871, 14042, 14043, 14044, 14045, 14100, 14101, 14103, 14104, 14106, 14107, 14108, 14111, 14112, 14128, 14130, 14132, 14134, 14136, 14137, 14138, 14139, 14140, 14141, 14142, 14143, 14144, 15047, 15059, 15060, 15061, 15064, 15065, 15068, 15069, 15070, 15071, 15072, 15073, 15074, 15075, 15076, 15077, 15078, 15079, 15080, 15081, 15082, 15083, 15084, 15085, 15086, 15087, 15088, 15090, 15091, 15092, 15093, 15094, 15095, 15096, 15138, 15802, 15995, 15999, 16004, 16007, 16008, 16009, 16022, 17015, 17016, 17704, 17721, 17723, 18238, 18407, 18408, 18409, 18413, 18486, 18504, 18506, 18508, 18634, 18637, 18638, 18639, 18948, 19043, 19044, 19047, 19048, 19049, 19050, 19051, 19052, 19056, 19057, 19058, 19059, 19998, 19999, 20476, 20477, 20478, 20479, 20480, 20481, 20537, 20538, 20539, 20549, 20550, 20551, 20575, 20818, 20820, 20821, 20823, 20827, 20828, 20830, 20831, 20832, 20833, 20906, 20907, 20909, 20950, 20954, 20955, 20956, 20958, 20959, 20960, 20961, 20966, 20967, 20969, 21154, 21542, 21748, 21753, 21754, 21755, 21756, 21758, 21760, 21763, 21764, 21765, 21766, 21767, 21769, 21774, 21775, 21777, 21778, 21779, 21780, 21784, 21789, 21790, 21791, 21792, 21793, 21931, 21932, 21933, 21934, 22195, 22197, 22660, 22756, 22757, 22758, 22759, 22760, 22761, 22762, 22763, 22764, 23761, 23762, 23763, 23824, 23825, 23835, 23836, 6473, 6833, 6835, 7953, 10328, 10329, 10330, 10331, 10332, 10333, 10399, 10400, 10401, 10402, 10403, 10410, 10411, 10412, 10413, 11728, 11729, 11730, 11731, 12422, 12424, 12425, 12426, 12427, 12428, 12429, 12939, 12940, 13183, 13218, 13388, 13389, 13390, 13391, 13392, 14611, 14612, 14614, 14615, 14616, 14620, 14621, 14622, 14623, 14624, 14626, 14629, 14631, 14632, 14633, 14636, 14637, 14638, 14640, 14641, 15045, 15046, 15048, 15049, 15050, 15051, 15052, 15053, 15054, 15055, 15056, 15057, 15058, 15062, 15063, 15066, 15067, 16369, 16391, 16392, 16393, 16396, 16397, 16401, 16403, 16405, 16406, 16409, 16410, 16413, 16414, 16415, 16416, 16417, 16418, 16419, 16420, 16421, 16422, 16423, 16424, 16425, 16426, 16427, 16428, 16429, 16430, 16431, 16432, 16433, 16434, 16435, 16436, 16485, 16487, 16489, 16490, 16491, 16492, 16494, 16496, 16498, 16499, 16501, 16502, 16503, 16504, 16505, 16506, 16507, 16508, 16509, 16510, 16513, 16514, 16515, 16516, 16518, 16519, 16521, 16522, 16523, 16524, 16525, 16526, 16527, 16528, 16530, 16531, 16666, 16667, 16668, 16669, 16670, 16671, 16672, 16673, 16674, 16675, 16676, 16677, 16678, 16679, 16680, 16681, 16682, 16683, 16684, 16685, 16686, 16687, 16688, 16689, 16690, 16691, 16692, 16693, 16694, 16695, 16696, 16697, 16698, 16699, 16700, 16701, 16702, 16703, 16704, 16705, 16706, 16707, 16708, 16709, 16710, 16711, 16712, 16713, 16714, 16715, 16716, 16717, 16718, 16719, 16720, 16721, 16722, 16723, 16724, 16725, 16726, 16727, 16728, 16729, 16730, 16731, 16732, 16733, 16734, 16735, 16736, 16737, 17562, 17564, 17566, 17567, 17568, 17569, 17570, 17571, 17572, 17573, 17576, 17577, 17594, 17596, 17598, 17599, 17600, 17601, 17610, 17611, 17612, 17613, 17616, 17617, 19682, 19683, 19684, 19685, 19686, 19687, 19688, 19689, 19690, 19691, 19692, 19693, 19694, 19695, 19863, 19873, 19893, 19898, 19905, 19912, 19920, 19925, 20041, 20042, 20043, 20044, 20045, 20046, 20047, 20048, 20049, 20050, 20051, 20052, 20053, 20054, 20150, 20154, 20159, 20163, 20167, 20171, 20186, 20190, 20195, 20199, 20204, 20208, 20295, 20296, 20406, 20407, 20408, 21278, 21524, 21525, 21994, 21996, 22000, 22001, 22002, 22004, 22007, 22008, 22010, 22011, 22016, 22017, 22062, 22063, 22067, 22068, 22070, 22071, 22072, 22073, 22078, 22079, 22082, 22085, 22086, 22088, 22092, 22093, 22095, 22098, 22100, 22101, 22106, 22108, 22111, 22112, 22301, 22302, 22303, 22304, 22305, 22306, 22311, 22313, 22843, 22852, 22855, 22856, 22857, 22858, 22859, 22860, 22862, 22863, 22864, 22865, 22867, 22868, 22869, 22870, 22872, 22873, 22874, 22875, 22876, 22877, 22878, 22879, 22880, 22881, 22882, 22883, 22884, 22885, 22886, 22887, 23078, 23081, 23082, 23084, 23085, 23087, 23088, 23089, 23090, 23091, 23092, 23093, 23243, 23244, 23251, 23252, 23253, 23254, 23255, 23256, 23257, 23258, 23259, 23260, 23261, 23262, 23263, 23264, 23272, 23273, 23274, 23275, 23276, 23277, 23278, 23279, 23280, 23281, 23282, 23283, 23284, 23285, 23286, 23287, 23288, 23289, 23290, 23291, 23292, 23293, 23294, 23295, 23296, 23297, 23298, 23299, 23300, 23301, 23302, 23303, 23304, 23305, 23306, 23307, 23308, 23309, 23310, 23311, 23312, 23313, 23314, 23315, 23316, 23317, 23318, 23319, 23324, 23493"

function Confirm-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $reply = Read-Host "Continue? (yes/abort)"
    if ($reply -ne "yes") { Write-Host "Aborted." -ForegroundColor Red; exit 1 }
}

function Invoke-LiveQuery {
    param([string]$Database, [string]$Query)
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 -N -e $Query $Database 2>$null
}

Write-Host "========================================" -ForegroundColor Red
Write-Host " ROLLBACK: mod-gear-ascension Phase 3" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "  This will remove all Phase 3 crafted/set item tier copies from live." -ForegroundColor White
Write-Host "  Phase 1/2 data (entries 300001-345833) will NOT be touched." -ForegroundColor White
Write-Host "  acore_characters is NOT affected." -ForegroundColor White
Write-Host ""

# Report current state
$currentCopies = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 345841 AND 356762"
$currentChain  = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_upgrade_chain"
Write-Host "  Current item_template 345841-356762: $currentCopies rows"
Write-Host "  Current item_upgrade_chain total:    $currentChain rows"
Write-Host ""

# Choose rollback option
Write-Host "Choose rollback option:" -ForegroundColor Cyan
Write-Host "  A = Surgical DELETE (preferred: fast, targeted, no snapshot needed)"
Write-Host "  B = Full snapshot restore (slow, complete; use only if Option A fails)"
Write-Host ""
$option = Read-Host "Enter A or B"

if ($option -ieq "A") {

    # ============================================================
    # OPTION A: Surgical DELETE
    # ============================================================
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " OPTION A: Surgical DELETE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Deletes:"
    Write-Host "    - item_upgrade_chain WHERE origin_entry IN (1093 bases)"
    Write-Host "    - item_template_locale WHERE ID BETWEEN 345841 AND 356762"
    Write-Host "    - item_template WHERE entry BETWEEN 345841 AND 356762"
    Write-Host ""

    Confirm-Step "Proceed with surgical DELETE on $WORLD_DB?"

    Write-Host "Deleting item_upgrade_chain rows..." -ForegroundColor Yellow
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB -e "DELETE FROM item_upgrade_chain WHERE origin_entry IN ($ORIGIN_ENTRIES);" 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: item_upgrade_chain DELETE failed." -ForegroundColor Red; exit 1 }
    Write-Host "OK: item_upgrade_chain rows removed." -ForegroundColor Green

    Write-Host "Deleting item_template_locale rows..." -ForegroundColor Yellow
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB -e "DELETE FROM item_template_locale WHERE ID BETWEEN 345841 AND 356762;" 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: item_template_locale DELETE failed." -ForegroundColor Red; exit 1 }
    Write-Host "OK: item_template_locale rows removed." -ForegroundColor Green

    Write-Host "Deleting item_template rows..." -ForegroundColor Yellow
    docker exec $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB -e "DELETE FROM item_template WHERE entry BETWEEN 345841 AND 356762;" 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: item_template DELETE failed." -ForegroundColor Red; exit 1 }
    Write-Host "OK: item_template rows removed." -ForegroundColor Green

    # Verify
    $remainCopies = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 345841 AND 356762"
    $remainChain  = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_upgrade_chain"
    $remainLocale = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template_locale WHERE ID BETWEEN 345841 AND 356762"
    Write-Host ""
    Write-Host "  item_template 345841-356762:       $remainCopies  (expected: 0)"
    Write-Host "  item_template_locale 345841-356762: $remainLocale  (expected: 0)"
    Write-Host "  item_upgrade_chain total:           $remainChain  (expected: 8480)"

    if ([int]$remainCopies -eq 0 -and [int]$remainLocale -eq 0 -and [int]$remainChain -eq 8480) {
        Write-Host "OK: Surgical rollback verified." -ForegroundColor Green
    } else {
        Write-Host "WARN: Some counts did not match expected post-rollback values. Manual inspection recommended." -ForegroundColor Yellow
    }

} elseif ($option -ieq "B") {

    # ============================================================
    # OPTION B: Full snapshot restore
    # ============================================================
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " OPTION B: Full snapshot restore" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    if (-not (Test-Path $SNAPSHOT_GZ)) {
        Write-Host "FAIL: Snapshot not found at $SNAPSHOT_GZ" -ForegroundColor Red
        Write-Host "      Snapshot was either not taken or was deleted." -ForegroundColor Red
        Write-Host "      Use Option A (surgical DELETE) instead." -ForegroundColor Red
        exit 1
    }
    $snapSizeMB = [math]::Round((Get-Item $SNAPSHOT_GZ).Length / 1MB, 1)
    Write-Host "  Snapshot: $SNAPSHOT_GZ ($snapSizeMB MB)"
    Write-Host ""
    Write-Host "  WARNING: This restores the ENTIRE acore_world database." -ForegroundColor Red
    Write-Host "  Any writes to OTHER acore_world tables since the snapshot will be LOST." -ForegroundColor Red
    Write-Host ""

    Confirm-Step "Stop ac-worldserver-v2 before restoring? (required for full restore)"
    docker stop $WS_CONTAINER 2>$null
    Write-Host "OK: $WS_CONTAINER stopped." -ForegroundColor Green

    Confirm-Step "Restore acore_world from snapshot? ALL post-snapshot changes will be LOST."
    Write-Host "Decompressing and restoring acore_world... (may take 5-15 minutes)" -ForegroundColor Yellow
    $startTime = Get-Date
    $decompressCmd = "gzip -dc `"$SNAPSHOT_GZ`""
    Invoke-Expression $decompressCmd | docker exec -i $DB_CONTAINER mysql -u $DB_USER -p$DB_PASS --default-character-set=utf8mb4 $WORLD_DB 2>$null
    $exitCode = $LASTEXITCODE
    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 0)

    if ($exitCode -ne 0) {
        Write-Host "FAIL: Snapshot restore failed (exit $exitCode, elapsed: ${elapsed}s)." -ForegroundColor Red
        Write-Host "      DB may be in a partial state. Do NOT restart worldserver." -ForegroundColor Red
        Write-Host "      Contact DBA." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: acore_world restored from snapshot in ${elapsed}s." -ForegroundColor Green

    # Verify
    $restoredChain = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_upgrade_chain"
    $restoredCopies = Invoke-LiveQuery -Database $WORLD_DB -Query "SELECT COUNT(*) FROM item_template WHERE entry BETWEEN 345841 AND 356762"
    Write-Host "  item_upgrade_chain total:    $restoredChain  (expected: 8480)"
    Write-Host "  item_template 345841-356762: $restoredCopies  (expected: 0)"

} else {
    Write-Host "Unknown option '$option'. Aborted." -ForegroundColor Red
    exit 1
}

# ============================================================
# Restart worldserver
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Restart live worldserver after rollback" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  The worldserver must restart to reload item_template after rollback."
Write-Host ""

$reply = Read-Host "Restart ac-worldserver-v2 now? (yes/skip)"
if ($reply -eq "yes") {
    Set-Location $REPO_ROOT
    docker compose up -d ac-worldserver
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: docker compose up -d ac-worldserver failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "OK: ac-worldserver-v2 restarted." -ForegroundColor Green
} else {
    Write-Host "Restart deferred. Run when ready:" -ForegroundColor Yellow
    Write-Host "  docker compose -f $REPO_ROOT\docker-compose.yml up -d ac-worldserver" -ForegroundColor Cyan
}

# ============================================================
# Optional: DBC revert (manual, only if DBC is suspected broken)
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host " OPTIONAL: Volume Item.dbc revert" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  The patched Item.dbc (56465 records) is on the shared volume."
Write-Host "  Rolling back the SQL does NOT require reverting the DBC."
Write-Host "  The extra DBC entries (345841-356762) are silently ignored while"
Write-Host "  those item_template rows are absent."
Write-Host ""
Write-Host "  Only revert the DBC if you suspect the DBC file is corrupted."
Write-Host "  In-volume backup is at: /data/dbc/Item.dbc.bak-pre-craftset"
Write-Host "  Host backup is at: $REPO_ROOT\.claude\dbc\_volume_Item.dbc.pre_craftset.bak"
Write-Host ""
Write-Host "  Manual DBC revert command (run yourself if needed):"
Write-Host "    docker exec ac-database-v2 cp /data/dbc/Item.dbc.bak-pre-craftset /data/dbc/Item.dbc"
Write-Host "  Then restart ac-worldserver-v2."
Write-Host ""

# ============================================================
# Done
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host " Rollback complete." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT POST-ROLLBACK STEPS:" -ForegroundColor Yellow
Write-Host "  1. Verify live is healthy (check docker logs $WS_CONTAINER)"
Write-Host "  2. Confirm 'Loaded 54739 Item Templates' in the worldserver log (pre-Phase3 count)"
Write-Host "  3. Document the failure reason in the package manifest:"
Write-Host "     $PKG_DIR\manifest.md"
Write-Host "  4. Report findings to the agent."
