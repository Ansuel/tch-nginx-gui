# Parse a current telephony.registry snapshot, never its historical log entries.
# LTE band ranges follow AOSP AccessNetworkUtils / 3GPP TS 36.101.
function number(text, name, tail) {
    if (!match(text, "(^|[^[:alnum:]_])" name "[[:space:]]*=[[:space:]]*")) return ""
    tail = substr(text, RSTART + RLENGTH)
    if (!match(tail, /^-?[0-9]+/)) return ""
    return substr(tail, RSTART, RLENGTH)
}
function valid(value, low, high) { return value != "" && value + 0 >= low && value + 0 <= high }
function band_range(band, low, high) { bands[++band_count] = band; first[band] = low; last[band] = high }
function earfcn_band(channel, i, band) {
    if (channel == "") return ""
    for (i = 1; i <= band_count; i++) {
        band = bands[i]
        if (channel + 0 >= first[band] && channel + 0 <= last[band]) return band
    }
    return ""
}
function report(key, value) { print key "|" (value == "" ? "N/A" : value) }
function metric(line, priority, value, segment) {
    if (!match(line, /CellSignalStrengthLte:[^,}]*/)) return
    segment = substr(line, RSTART, RLENGTH)
    value = number(segment, "rsrp")
    if (valid(value, -140, -43) && priority > rp_priority) { rsrp = value; rp_priority = priority }
    value = number(segment, "rsrq")
    if (valid(value, -34, 3) && priority > rq_priority) { rsrq = value; rq_priority = priority }
    value = number(segment, "rssnr")
    if (valid(value, sdk >= 30 ? -20 : -200, sdk >= 30 ? 30 : 300) && priority > sn_priority) {
        rssnr = value; sn_priority = priority
    }
}
function identity(line, priority, segment, list, count, array, i, value) {
    if (priority <= identity_priority || !match(line, /CellIdentityLte:[^}]*/)) return
    segment = substr(line, RSTART, RLENGTH)
    eci = number(segment, "mCi"); pci = number(segment, "mPci")
    tac = number(segment, "mTac"); channel = number(segment, "mEarfcn")
    mcc = number(segment, "mMcc"); mnc = number(segment, "mMnc")
    explicit_bands = ""
    if (match(segment, /mBands[[:space:]]*=[[:space:]]*\[[^]]*\]/)) {
        list = substr(segment, RSTART, RLENGTH)
        sub(/^[^[]*\[/, "", list); sub(/\].*$/, "", list)
        count = split(list, array, /[ ,]+/)
        for (i = 1; i <= count; i++) {
            value = array[i]
            if (value ~ /^[0-9]+$/ && valid(value, 1, 88)) {
                explicit_bands = explicit_bands (explicit_bands == "" ? "" : ", ") "B" (value + 0)
            }
        }
    }
    identity_priority = priority
}
BEGIN {
    phone = "0"; slots[phone] = 1
    band_range(1, 0, 599); band_range(2, 600, 1199); band_range(3, 1200, 1949)
    band_range(4, 1950, 2399); band_range(5, 2400, 2649); band_range(6, 2650, 2749)
    band_range(7, 2750, 3449); band_range(8, 3450, 3799); band_range(9, 3800, 4149)
    band_range(10, 4150, 4749); band_range(11, 4750, 5009); band_range(12, 5010, 5179)
    band_range(13, 5180, 5279); band_range(14, 5280, 5379)
    band_range(17, 5730, 5849); band_range(18, 5850, 5999); band_range(19, 6000, 6149)
    band_range(20, 6150, 6449); band_range(21, 6450, 6599); band_range(22, 6600, 7399)
    band_range(23, 7500, 7699); band_range(24, 7700, 8039); band_range(25, 8040, 8689)
    band_range(26, 8690, 9039); band_range(27, 9040, 9209); band_range(28, 9210, 9659)
    band_range(29, 9660, 9769); band_range(30, 9770, 9869); band_range(31, 9870, 9919)
    band_range(32, 9920, 10359); band_range(33, 36000, 36199); band_range(34, 36200, 36349)
    band_range(35, 36350, 36949); band_range(36, 36950, 37549); band_range(37, 37550, 37749)
    band_range(38, 37750, 38249); band_range(39, 38250, 38649); band_range(40, 38650, 39649)
    band_range(41, 39650, 41589); band_range(42, 41590, 43589); band_range(43, 43590, 45589)
    band_range(44, 45590, 46589); band_range(45, 46590, 46789); band_range(46, 46790, 54539)
    band_range(47, 54540, 55239); band_range(48, 55240, 56739); band_range(49, 56740, 58239)
    band_range(50, 58240, 59089); band_range(51, 59090, 59139); band_range(52, 59140, 60139)
    band_range(53, 60140, 60254); band_range(65, 65536, 66435); band_range(66, 66436, 67365)
    band_range(67, 67366, 67535); band_range(68, 67536, 67835); band_range(70, 68336, 68585)
    band_range(71, 68586, 68935); band_range(72, 68936, 68985); band_range(73, 68986, 69035)
    band_range(74, 69036, 69465); band_range(85, 70366, 70545); band_range(87, 70546, 70595)
    band_range(88, 70596, 70645)
}
/^[[:space:]]*local logs:/ { historical = 1 }
historical { next }
/^[[:space:]]*mActiveDataSubId=/ { active_sub = number($0, "mActiveDataSubId"); next }
/^[[:space:]]*mDefaultSubId=/ { default_sub = number($0, "mDefaultSubId"); next }
/^[[:space:]]*mDefaultPhoneId=/ { default_phone = number($0, "mDefaultPhoneId"); next }
/^[[:space:]]*Phone Id=/ {
    phone = $0; sub(/^.*Phone Id=/, "", phone); sub(/[^0-9].*$/, "", phone)
    slots[phone] = 1
}
{
    snapshot[phone] = snapshot[phone] $0 "\n"
    if ($0 ~ /mDataConnectionState[[:space:]]*=[[:space:]]*2([^0-9]|$)/) score[phone] += 100
    if ($0 ~ /mDataRegState[[:space:]]*=[[:space:]]*0\(/) score[phone] += 20
    if ($0 ~ /mCellIdentity=CellIdentity(Lte|Nr)/) score[phone] += 10
}
END {
    selected = "0"; best = -1
    for (slot in slots) {
        weight = score[slot] + 0
        if (active_sub != "" && active_sub == default_sub && slot == default_phone && weight > 0) weight += 1000
        if (weight > best || (weight == best && slot + 0 < selected + 0)) { selected = slot; best = weight }
    }
    if (mode == "select") { printf "%s", snapshot[selected]; exit }
    count = split(snapshot[selected], rows, /\n/)
    for (i = 1; i <= count; i++) {
        line = rows[i]
        if (line ~ /^[[:space:]]*mSignalStrength=/) metric(line, 100)
        if (line ~ /^[[:space:]]*mCellIdentity=CellIdentityLte/) identity(line, 100)
        if (line ~ /^[[:space:]]*mCellIdentity=CellIdentityNr/) primary_nr = 1
        if (line ~ /^[[:space:]]*mCellInfo=/ && line ~ /mRegistered=YES/) {
            # Use only the registered entry, never the tail of the neighbour list.
            segment = line
            while (match(segment, /CellInfoLte:\{/)) {
                segment = substr(segment, RSTART)
                end_entry = index(substr(segment, 2), "CellInfo")
                entry = end_entry ? substr(segment, 1, end_entry) : segment
                if (entry ~ /mRegistered=YES/) { identity(entry, 10); metric(entry, 10); break }
                segment = substr(segment, 2)
            }
        }
        if (line ~ /^[[:space:]]*mPhysicalChannelConfigs=/) {
            entries = split(line, carriers, /\},[[:space:]]*\{/)
            for (carrier = 1; carrier <= entries; carrier++) {
                segment = carriers[carrier]
                if (segment ~ /mConnectionStatus=PrimaryServing/ && segment ~ /mNetworkType=LTE([^[:alnum:]_]|$)/) {
                    physical_band = number(segment, "mBand")
                    physical_pci = number(segment, "mPhysicalCellId")
                    break
                }
            }
        }
    }
    if (primary_nr && identity_priority < 100) { eci = ""; pci = ""; tac = ""; channel = ""; explicit_bands = ""
        physical_pci = ""; physical_band = "" }
    if (!valid(eci, 0, 268435455)) eci = ""
    if (!valid(pci, 0, 503)) pci = valid(physical_pci, 0, 503) ? physical_pci : ""
    if (!valid(tac, 0, 65535)) tac = ""
    if (!valid(channel, 0, 262143)) channel = ""
    band = explicit_bands; band_source = band == "" ? "" : "Android"
    if (band == "" && !primary_nr && valid(physical_band, 1, 88)) { band = "B" (physical_band + 0); band_source = "Android" }
    if (band == "" && !primary_nr) {
        derived = earfcn_band(channel)
        if (derived != "") { band = "B" derived; band_source = "EARFCN" }
    }
    if (eci != "") { enb = int(eci / 256); sector = eci % 256 }
    if (eci != "" && mcc ~ /^[0-9]+$/ && length(mcc) == 3 && mnc ~ /^[0-9]+$/ && (length(mnc) == 2 || length(mnc) == 3)) ecgi = mcc "-" mnc "-" sprintf("%.0f", eci)
    if (rssnr != "") {
        if (sdk >= 30) snr = sprintf("%g dB", rssnr)
        else if (sdk > 0) snr = sprintf("%g dB", rssnr / 10)
        else snr = rssnr " (scala Android non disponibile)"
    }
    report("SIGNAL_RAW", rsrp); report("RSRQ", rsrq); report("SNR", snr)
    report("PCI", pci); report("BAND", band); report("BAND_SOURCE", band_source)
    report("EARFCN", channel); report("ECI", eci); report("ENB", enb); report("SECTOR", sector)
    report("ECGI", ecgi); report("TAC", tac); report("SIM_SLOT", selected + 1)
}
