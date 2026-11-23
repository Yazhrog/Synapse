import QtQuick
import qs.src.components.base
import qs.src.core
import qs.src.services.system
import qs.src.theme
Item {
    id: root

    // The system services are singletons that poll only while leased: this
    // page holds a lease on each while it is shown.
    readonly property var cpu:     CpuService
    readonly property var mem:     MemService
    readonly property var net:     NetService
    readonly property var thermal: ThermalService
    readonly property var fan:     FanControl
    readonly property var disk:    DiskService
    readonly property var envy:    GpuModeService
    readonly property var cpuFreq: CpuFreqService
    readonly property var gpu:     GpuService

    Lease { service: CpuService;     active: root.visible }
    Lease { service: MemService;     active: root.visible }
    Lease { service: NetService;     active: root.visible }
    Lease { service: ThermalService; active: root.visible }
    Lease { service: DiskService;    active: root.visible }
    Lease { service: CpuFreqService; active: root.visible }
    Lease { service: GpuService;     active: root.visible }

    Column {
        anchors {
            fill:          parent
            bottomMargin:  8
            topMargin:     8
        }
        spacing: 8

        // Speedometers
        Row {
            id:      speedoRow
            width:   parent.width
            anchors.topMargin: 4
            height:  160
            spacing: 8

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "CPU"
                    percent:     cpu.usagePercent
                    centerText:  cpu.usagePercent + "%"
                    bottomText:  cpuFreq.curFreqStr
                    active:      true
                    accentColor: Theme.active
                }
            }

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "RAM"
                    percent:     mem.usagePercent
                    centerText:  mem.usagePercent + "%"
                    bottomText:  mem.usedStr + " / " + mem.totalStr
                    active:      true
                    accentColor: "#cba6f7"
                }
            }

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "iGPU"
                    percent:     gpu.igpu.freqPercent
                    centerText:  gpu.igpu.freqPercent + "%"
                    bottomText:  gpu.igpu.curMhz
                    active:      true
                    accentColor: "#89dceb"
                }
            }

            StatCard {
                width:  (parent.width - parent.spacing * 3) / 4
                height: parent.height
                Speedometer {
                    anchors.centerIn: parent
                    label:       "dGPU"
                    percent:     gpu.dgpu.active ? gpu.dgpu.usagePercent : 0
                    centerText:  gpu.dgpu.active ? (gpu.dgpu.usagePercent + "%") : "0%"
                    bottomText:  gpu.dgpu.active ? (gpu.dgpu.usedVram + " / " + gpu.dgpu.totalVram) : ""
                    active:      gpu.dgpu.active
                    accentColor: "#a6e3a1"
                }
            }
        }
        
        Row{
            width:   parent.width
            height:  100
            spacing: 8
            // Thermal strip
            StatCard {
                width:   (parent.width-parent.spacing)/2
                height:  parent.height
                padding: 6
    
                TempPanel {
                    anchors.fill: parent
                    service:      thermal
                    dgpuActive:   gpu.dgpu.active
                }
            }
            
            // Fan control strip
            StatCard {
                width:   (parent.width-parent.spacing)/2
                height:  parent.height
                padding: 6
                
                FanPanel {
                    anchors.fill: parent
                    service:      fan
                }
            }
        }
        // Net | Disk | Power
        Row {
            width:   parent.width
            height:  parent.height - speedoRow.height - 100 - parent.spacing 
            spacing: 8

            // Network — narrow, only 3 rows
            StatCard {
                width:  Math.round(parent.width * 0.20)
                height: parent.height
                NetStatsPanel {
                    anchors.fill: parent
                    service:      net
                }
            }

            // Disks — moderate, horizontal bars stack vertically
            StatCard {
                width:  Math.round(parent.width * 0.35)
                height: parent.height
                DiskPanel {
                    anchors.fill: parent
                    service:      disk
                }
            }

            // Power — widest, two button rows need space
            StatCard {
                width:  parent.width - Math.round(parent.width * 0.20) - Math.round(parent.width * 0.35) - parent.spacing * 2
                height: parent.height
                PowerPanel {
                    anchors.fill:   parent
                    cpuFreqService: cpuFreq
                    envyService:    envy
                }
            }
        }
    }
}
