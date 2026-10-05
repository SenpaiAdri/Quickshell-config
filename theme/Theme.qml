// Design tokens for the OSD shell. Single place to tune look & feel.
pragma Singleton

import QtQuick

QtObject {
    // --- window ---
    property int windowWidth: 340
    property int windowHeight: 64
    property int bottomMargin: 90
    property int hideAfterMs: 1500

    // --- pill ---
    property int pillWidth: 330
    property int pillHeight: 50
    property int pillRadius: 14
    property color pillBg: "#e6141414"
    property color pillBorder: "#26ffffff"
    property int pillBorderWidth: 1
    property int rowSpacing: 14

    // --- icon ---
    property int iconBoxWidth: 20
    property color iconColor: "#ececec"
    property string iconFont: "FantasqueSansM Nerd Font"
    property int iconSize: 22
    // Volume tier cutoffs (low < lowMax, mid < midMax, else high)
    property int iconLowMax: 35
    property int iconMidMax: 70

    // --- slider ---
    property int trackWidth: 190
    property int trackHeight: 6
    property int trackRadius: 3
    property color trackBg: "#33ffffff"
    property color fillColor: "#BABABA"

    // --- label ---
    property int labelNumWidth: 25
    property int labelMicWidth: 50
    property color labelColor: "#BABABA"
    property string labelFont: "Poppins"
    property int labelSize: 13

    // --- wifi menu ---
    property int wifiDot: 48
    property int wifiWidth: 400
    property int wifiHeight: 460
    property int wifiTopMargin: 28
    property int wifiRightMargin: 8
    property int wifiRadius: 16
    property color wifiBg: "#e6141414"
    property color wifiBorder: "#26ffffff"
    property int wifiPadding: 20
    property int wifiHeaderHeight: 56
    property int wifiFooterHeight: 52
    property int wifiRowHeight: 52
    property int wifiRowRadius: 10
    property color wifiRowHover: "#14ffffff"
    property color wifiText: "#ececec"
    property color wifiDim: "#BABABA"
    property string wifiFont: "Poppins"
    property int wifiTitleSize: 14
    property int wifiBodySize: 13
    property int wifiSmallSize: 11
    property color wifiAccent: "#ececec"

    // --- wallpaper filmstrip picker ---
    property int wallWidth: 700
    property int wallHeight: 236
    property int wallBottomMargin: 90
    property int wallRadius: 18
    property color wallBg: "#e6141414"
    property color wallBorder: "#26ffffff"
    property int wallPadding: 20
    property int wallSpacing: 18
    property int wallThumbW: 200
    property int wallThumbH: 120
    property real wallActiveScale: 1.15
    property real wallSideScale: 0.85
    property int wallSlideMs: 240
    property int wallPopMs: 180
    property color wallThumbBorder: "#26ffffff"
    property color wallActiveBorder: "#ececec"
    property real wallSideOpacity: 0.55

    // --- app launcher (rofi drun replacement) ---
    property int launcherWidth: 560
    property int launcherTopMargin: 220
    property int launcherRadius: 18
    property color launcherBg: "#e6141414"
    property color launcherBorder: "#26ffffff"
    property int launcherPadding: 16
    property int launcherRowHeight: 52
    property int launcherRowRadius: 12
    property color launcherRowHover: "#14ffffff"
    property color launcherRowSelected: "#1effffff"
    property color launcherText: "#ececec"
    property color launcherDim: "#BABABA"
    property string launcherFont: "Poppins"
    property int launcherTitleSize: 14
    property int launcherBodySize: 13
    property int launcherSmallSize: 11

    // --- power menu (wlogout replacement, centered icon grid) ---
    property int powerWidth: 640
    property int powerTileW: 104
    property int powerTileH: 128
    property int powerIconSize: 34
    property int powerRadius: 18
    property color powerBg: "#e6141414"
    property color powerBorder: "#26ffffff"
    property int powerPadding: 20
    property int powerSpacing: 12
    property color powerTileBg: "#0dffffff"
    property color powerTileBorder: "#33ffffff"
    property color powerTileSelected: "#1effffff"
    property color powerDanger: "#f38ba8"
    property color powerText: "#ececec"
    property color powerDim: "#BABABA"
    property string powerFont: "Poppins"
    property int powerLabelSize: 13
    property int powerKeySize: 11

    // --- dynamic island clock/calendar ---
    property int islandDot: 48
    property int islandExpandedW: 400
    property int islandExpandedH: 424
    property int islandTopMargin: 2
    property int islandRadiusExpanded: 24
    property color islandBg: "#e6141414"
    property color islandBorder: "#26ffffff"
    property color islandHover: "#14ffffff"
    property color islandText: "#ececec"
    property color islandDim: "#BABABA"
    property color islandAccent: "#ececec"
    property color islandTodayBg: "#ececec"
    property color islandTodayText: "#141414"
    property string islandFont: "Poppins"
    property int islandHeroSize: 44
    property int islandSubSize: 13
    property int islandBodySize: 13
    property int islandSmallSize: 11
    property int islandPadding: 20

    // --- notifications: macOS-banner layout, dark theme ---
    property int notifWidth: 380
    property int notifTopMargin: 28
    property int notifRightMargin: 12
    property int notifSpacing: 10
    property int notifRadius: 18
    property color notifBg: "#e6141414"
    property color notifBorder: "#26ffffff"
    property color notifHover: "#14ffffff"
    property int notifPadding: 14
    property color notifText: "#ececec"
    property color notifDim: "#BABABA"
    property color notifAccent: "#ececec"
    property color notifCritical: "#f38ba8"
    property color notifLow: "#6c6c6c"
    property color notifRowBg: "#0dffffff"
    property color notifDivider: "#14ffffff"
    property string notifFont: "Poppins"
    property int notifTitleSize: 13
    property int notifBodySize: 13
    property int notifSmallSize: 11
    property int notifMaxShown: 5
    property int notifTimeoutMs: 6000
    property int centerWidth: 400
    property int centerHeight: 520
    // Dot the center morphs from — same language as the island dot.
    property int centerDot: 48
}
