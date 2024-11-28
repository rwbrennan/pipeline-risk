extensions [ gis ]

breed [raindrops raindrop]
breed [sensors sensor]
breed [cells cell]

sensors-own [
  sensor-no  ;; sensor number
]

globals [
  elevation
  slope               ;; rate of change of elevation for each DEM pixel
  aspect              ;; slope direction
  border              ;; defines the border of the worldview
  sensor-selected     ;; the sensor selected for plotting (sensor number)
  sensor-who          ;; the sensor selected for plotting (turtle number)
  start-x             ;; pxcor for the start of the pipeline
  start-y             ;; pycor for the start of the pipeline
  end-x               ;; pxcor for the end of the pipeline
  end-y               ;; pycor for the end of the pipeline
  number-of-sensors   ;; number of sensors in the pipeline (evenly spaced over length)
  cell-mean-x         ;; storm cell mean pxcor
  cell-sd-x           ;; storm cell Std Dev pxcor
  cell-mean-y         ;; storm cell mean pycor
  cell-sd-y           ;; storm cell Std Dev pycor
  cell-rain-rate      ;; storm cell rain rate
  cell-speed          ;; storm cell speed
  cell-heading        ;; storm cell heading (0 is north, 90 is east, and so on)
]

to setup
  clear-all
  ;; DEM Data
  ;; - first two lines declare the number of columns and rows of pixels
  ;; - the resize-world command can be used to make the worldview equivalent
  ;; - the numbers can correspond exactly or proportionally (check this)
  ;; - it would be interesting to set this up automatically (read .asc file, use ncols/nrows to set worldview)
  set elevation gis:load-dataset "data/Airdrie-to-Bowden.asc"
  resize-world 0 149 0 225
  gis:set-world-envelope gis:envelope-of elevation
  let horizontal-gradient gis:convolve elevation 3 3 [ 1 1 1 0 0 0 -1 -1 -1 ] 1 1
  let vertical-gradient gis:convolve elevation 3 3 [ 1 0 -1 1 0 -1 1 0 -1 ] 1 1
  set slope gis:create-raster gis:width-of elevation gis:height-of elevation gis:envelope-of elevation
  set aspect gis:create-raster gis:width-of elevation gis:height-of elevation gis:envelope-of elevation
  let x 0
  repeat (gis:width-of slope)
  [ let y 0
    repeat (gis:height-of slope)
    [ let gx gis:raster-value horizontal-gradient x y
      let gy gis:raster-value vertical-gradient x y
      if ((gx <= 0) or (gx >= 0)) and ((gy <= 0) or (gy >= 0))
      [ let s sqrt ((gx * gx) + (gy * gy))
        gis:set-raster-value slope x y s
        ifelse (gx != 0) or (gy != 0)
        [ gis:set-raster-value aspect x y atan gy gx ]
        [ gis:set-raster-value aspect x y 0 ] ]
      set y y + 1 ]
    set x x + 1 ]
  gis:set-sampling-method aspect "bilinear"
  gis:paint elevation 0
  set border patches with [ count neighbors != 8 ]
  create-pipeline
  set sensor-selected 1
  ;; Create the storm cell(s)
  create-cells 1
  [
    set size 4
    set shape "x"
    set color green
    set heading cell-heading
    set label (word "(" cell-sd-x ", " cell-sd-y ")")
    move-to patch cell-mean-x cell-mean-y
  ]
  reset-ticks
end

to go
  ;; Create the rainfall
  weather-pattern cell-mean-x cell-sd-x cell-mean-y cell-sd-y cell-rain-rate
  ;; Move storm cell(s)
  ask cells
  [
    if ticks mod cell-speed = 0
    [
      ifelse not member? patch-here border
      [
        ;; move across the worldview
        fd 1
        set cell-mean-x pxcor
        set cell-mean-y pycor
      ]
      [
        ;; diminish (for now just diminish by 10% per increment)
        set cell-rain-rate floor ( cell-rain-rate * 0.9 )
      ]
    ]
  ]
  ;; Allow the rain to flow downslope based on the DEM
  ask raindrops
  [ forward random-normal 0.1 0.1
    let h gis:raster-sample aspect self
    ifelse h >= -360
    [ set heading subtract-headings h 180 ]
    [ die ] ]
  ;; Stop the simulation once all of the rain has left the worldview
  ;if not any? raindrops
  ;[ stop ]

  ;; Remove the raindrops when they flow to the border of the worldview
  ask border
  [
    ask raindrops-here [ die ]
  ]

  ;; This code allows the user to select individual pipeline sensors for inspection
  ;; - when the user clicks on a sensor, the "flow" around the sensor is shown in the Rainfall plot
  ;; - when the user clicks on a sensor, the sensor colour changes to red
  ;; - if the user selects inspect-sensor?, an inspection window is opened for the sensor
  if mouse-down? and any? sensors-on patch mouse-xcor mouse-ycor
  [
    ask sensors-on patch mouse-xcor mouse-ycor
    [
      set sensor-selected sensor-no
      stop-inspecting sensor sensor-who
      set sensor-who who
      if inspect-sensor? [ inspect sensor sensor-who ]
    ]
    set-current-plot "Flow"
    clear-plot
  ]
  ask sensors
  [
    ifelse sensor-no = sensor-selected
    [ set color red ]
    [ set color yellow ]
  ]

  ;; When draw? is selected by the user, the path of each raindrop is drawn on the worldview
  ifelse draw?
    [ ask raindrops [ pen-down ] ]
    [ ask raindrops [ pen-up ] ]

  tick
end

to create-pipeline
  ;; This procedure is used to create the pipeline on the map
  ;; - pipleine includes sensor points that are evenly spaced from start to end sensor
  ;; - each sensor is connected by a link
  read-pipeline-data
  let x-spacing ((start-x - end-x) / (number-of-sensors - 1))
  let i 0
  let sensor-x 0
  let sensor-y 0
  let my-sensor-no 0
  while [ i < number-of-sensors ]
  [
    create-sensors 1 [
      set sensor-x (start-x - i * x-spacing)
      set sensor-y ((end-y - start-y) / (end-x - start-x)) * (sensor-x - start-x) + start-y
      setxy sensor-x sensor-y
      set color yellow
      set size 1.5
      set shape "circle"
      set sensor-no i + 1
      set my-sensor-no sensor-no
      if i > 0 [
        create-links-with sensors with [ sensor-no = my-sensor-no - 1 ]
      ]
    ]
    set i i + 1
  ]
end

to read-pipeline-data
  ;; This procedure is used to read from a text file that specifies the pipeline
  ;; The format of the file is:
  ;; <pxcor of start of pipeline> <pycor of start of pipeline>
  ;; <pxcor of end of pipeline> <pycor of end of pipeline>
  ;; <number of pipeline sensors>
  ;; <cell-mean-x> <cell-sd-x> <cell-mean-y> <cell-sd-y> <cell-rain-rate> <cell-speed> <cell-heading>
  file-open "data/Airdrie-to-Bowden-APPL.txt"
  while [ not file-at-end? ]
  [
    set start-x file-read
    set start-y file-read
    set end-x file-read
    set end-y file-read
    set number-of-sensors file-read
    set cell-mean-x file-read
    set cell-sd-x file-read
    set cell-mean-y file-read
    set cell-sd-y file-read
    set cell-rain-rate file-read
    set cell-speed file-read
    set cell-heading file-read
  ]
  file-close
end

to weather-pattern [ mean-pxcor stdev-pxcor mean-pycor stdev-pycor rain-rate ]
  ;; This procedure is used to move raindrops to a location on the worldview that
  ;; follows a moving weather pattern
  ;;
  let i 0
  let drop-pxcor 0
  let drop-pycor 0
  while [ i < rain-rate ]
  [
    set drop-pxcor random-normal mean-pxcor stdev-pxcor
    set drop-pycor random-normal mean-pycor stdev-pycor
    if drop-pxcor < max-pxcor and drop-pxcor > 0 and drop-pycor < max-pycor and drop-pycor > 0
    [
      create-raindrops 1
      [
        set size 0.6
        set shape "circle"
        set color blue
        move-to patch drop-pxcor drop-pycor
      ]
    ]
    set i i + 1
  ]



end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
1118
1375
-1
-1
6.0
1
10
1
1
1
0
0
0
1
0
149
0
225
1
1
1
ticks
30.0

BUTTON
13
29
79
62
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
96
30
159
63
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
12
75
147
108
Display Elevation
gis:paint elevation 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
12
114
147
147
Display Slope
gis:paint slope 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
12
154
146
187
Display Aspect
gis:paint aspect 0
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
12
239
115
272
draw?
draw?
1
1
-1000

PLOT
4
400
204
550
Flow
NIL
NIL
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -14454117 true "" "ask sensor (sensor-selected - 1) [ plot count raindrops-on neighbors ]\n"

MONITOR
9
350
122
395
NIL
sensor-selected
17
1
11

SWITCH
8
313
151
346
inspect-sensor?
inspect-sensor?
0
1
-1000

PLOT
3
564
203
714
Rainfall
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count raindrops"

@#$#@#$#@
## WHAT IS IT?

This model simulates raifall over a geographic area. The intention is to determine the risk of infrastructure damage (in this case, an energy pipeline) resulting from adverse weather conditions. The ultimate goal is to identify risk at points along a pipeline for various weather conditions.

## HOW IT WORKS

The model loads a digtial elevation model (DEM) in ASCII .asc format on _Setup_. The DEM can be prepared using [QGIS](https://www.qgis.org/) and the [OpenTopography DEM](https://opentopography.org/) plugin. The worldview is adjusted during setup based on the size of the DEM (i.e., number of columns and rows in the .asc file).

Additionally, on _Setup_ a text file is read to load the pipeline and storm cell data. The format of the file is as follows:

```
<pxcor of start of pipeline> <pycor of start of pipeline>
<pxcor of end of pipeline> <pycor of end of pipeline>
<number of pipeline sensors>
<cell-mean-x> <cell-sd-x> <cell-mean-y> <cell-sd-y> <cell-rain-rate> <cell-speed> <cell-heading>
```

The `<cell speed>` parameter is really a rate: i.e., number of ticks until a forward movement of 1.

The _Go_ routine creates raindrops at random locations around a moving centroid (storm cell) at the specified _rain-rate_. This storm cell is shown by a green X on the worldview and labelled with its "size" (std deviation in x and y directions). Raindrops flow downstream based on the slope of the landscape (determined by the DEM). Raindrops are represented by blue dots. 

## HOW TO USE IT

The model includes the following options:

* _Setup_ Button: loads the DEM and the pipeline data files.
* _Go_ Button: creates raindrops at the specified _rain-rate_.
* _Display Elevation_ Button: renders the worldview by elevation (This is the default view).
* _Display Slope_ Button: renders the worldview by slope (rate of change of elevation for each DEM pixel).  
* _Display Aspect_ Button: renders the worldview by aspect (slope direction).
* _draw?_ Selector: draws the path of each raindrop.
* _inspect-sensor_ Selector: allows the user to select the `inspect sensor` feature; when selected, a window opens showing the details the sensor that is selected (clicked on).
* _Flow_ Plot: this plot shows the current number of raindrops around the sensor (a rough indicator of the current flow of water at the sensing point); different sensing locations can be selected by clicking on a pipeline sensor; when selected, the sensor changes from yellow to red and the Rainfall plot shows data at the sensor point.
* _Rainfall_ Plot: this plot shows the total amount of rainfall (raindrops) in the worldview

## EXTENDING THE MODEL

Ultimately, the model will be used to generate a database of rainfall cases for various weather parameters. The input parameters could be similar to what one would obtain from a weather forcast (e.g., storm direction, speed, intensity, etc.). The output parameters will be taken at various points along the pipeline and will relate to risk of pipeline failure (most likely maximum flow rate at the point). 

The plan for model extension is as follows:

  * Pipeline: 
    * currently, only a straight pipeline section can be specified; it would be helpful to be able to specify bends in the pipeline (see the APPL pipeline in Google Earth)
    * it would be interesting to have the _sensor_ nodes change in appearance based on the flow at the sensor; this could be a change in colour and/or size of the sensor point
  * Weather Pattern:
    * a single weather pattern moves through the geographic area by having the rainfall occur around a centroid (i.e., the centre of the weather pattern)
    * could multiple storm cells be added (this will likely require the centroid parameters to be moved from global to local (to the cell type) or changed to a list; as well as some changes to the code to reflect this
  * Rainfall:
    * currently, raindrops move downslope at the same rate regardless of the slope
    * it would be interesting to have the flow rate change based on the difference in slope
  * Scales:
    * it would be helpful to have a sense of various scales in the model (currently, everything is dimensionless)
    * distances: can we get a measure of the distance scale (in kilometers) from the DEM data?
    * rain rate and flow: can we get a rough sense of this?
  * Experiments:
    * each experiment would generate a data point for a given weather condition
    * multiple experiments across a range of parameters would create a database for an ML model
    * this database could cover the entire pipleine (for now we are just looking at one section of the APPL line)

## IDEAS

### Multiple Storm Cells

As noted above, the option for multiple storm cells should be added. From an input data perspective, this could just be a matter of adding extra storm cell lines to the input data file.

### Storm Cell at Boundary

When the storm centroid reaches the boundary, the current model decreases the rain rate by 10% at each step (i.e., based on the cell centroid speed). This is not quite right as the size of the cell (within the boundaries) is also decreasing. The current approach is likely a good approximation, though it would be worthwhile to investigate this part of the model more closely.

### Data Collection

Data needs to be collected at each of the sensor points. For example:

  * location of sensor: could this be obtained from the DEM?
  * water flow: current flow, maximum flow, flow profile

## NETLOGO FEATURES

This model uses the [Netlogo GIS extension](https://ccl.northwestern.edu/netlogo/docs/gis.html).

## RELATED MODELS

This model uses features of the _Grand Canyon_ model and the _GIS Gradient Example_ model from the Netlogo Models Library.

## CREDITS AND REFERENCES

Copyright 2024 Robert W. Brennan.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons Licence" style="border-width:0" src="https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
<!-- 2024 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
