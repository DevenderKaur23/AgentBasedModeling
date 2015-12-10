;;; Model created by Lindsay T Mico
;;; See https://github.com/LTMico/AgentBasedModeling for more info and the GIS files needed to run this
;;; Note that in theory any watershed could be modeled if the data is available

;;; A few helpful notes
;;; note that all values from gis must be caps
;;; ALSO NOTE THAT THIS MODEL RUNS WELL WITH 300 X 300
;;; Note that the patch size is 15.75165m based on prelim GIS analysis of the exported raster files

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [ gis ]

globals   [ 
          rivers-dataset 
          slope-dataset
          floodplain-dataset
          vegetation-dataset
          watershed-dataset
          elevation-dataset
          water-patches ; agent set of all patches with water
          section-dataset
          fp-dataset
          ]

patches-own  [
             water 
             vegtype 
             age 
             slope 
             elevation 
             heightm 
             diamcm 
             sinuosity 
             sin-count 
             grad
             acw
             id
             ipcoho
             ipsteelhead
             section
             vwi
             num
             ]


turtles-own  [
             len 
             diameter 
             age_turtle 
             veg_class ;;Note this isnt used yet
             size_ratio ; len/acw
             stickiness
             ]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Setup procedure run by the button on the 'Interface' tab
;; Consider moving the GIS setup to a new sub-routine
to setup
  clear-all
  
  ;;Load all of the GIS datasets and defuine the envelope of the model
  set slope-dataset gis:load-dataset "slope.shp"
  gis:set-world-envelope gis:envelope-of slope-dataset  
  set rivers-dataset gis:load-dataset "Killam_Stream_ACW.shp" 
  set watershed-dataset gis:load-dataset "KillamCreek.shp"
  set elevation-dataset gis:load-dataset "elevation.shp"  
  set vegetation-dataset gis:load-dataset "Vegprj.shp" 
  set section-dataset gis:load-dataset "plssprj.shp" 
  set fp-dataset gis:load-dataset "Killam_Stream_FP2.shp"
  
  define-acw
  set water-patches patches with [water = 1] ;; defines an agentset of what is water and what is not
                                                     
  define-slope
  define-elevation
  display-watershed
  define-veg
  spawn-lwd
  
  ask patches [define-sincount]
  ask patches [set id ( word pxcor "x" pycor "y" ) ]
  
  ;;Here is the code to export a raster in asc format
  ;;Note that Arcmap can't accept the NaN value - it must be a number in the header and the file
  ;;so I got around this by changing the extensions to txt and then replacing NaN with -9999
  ;;after this I convert from asc to a raster
  ;;then to a polygon
  ;;then used identity to overlay the two files so I have one polygon with both x and y
  ;;then to a geodatabase
  
  gis:store-dataset ( gis:patch-dataset pxcor ) "outrastx" 
  gis:store-dataset ( gis:patch-dataset pycor ) "outrasty"
   
  reset-ticks
  
;; this part opens the output file for later output
;; note that I write out almost everything just in case Im interested later
;; this output file is intended to work together with an R script
;; therefore there is no analysis done inside of NetLogo - it all takes place in R (and GIS)
if (file-exists? "LWDOutput.csv") [file-delete "LWDOutput.csv" ] 
file-open "LWDOutput.csv"
file-type "ticks,"
file-type "pxcor,"
file-type "pycor,"
file-type "id,"
file-type "diam,"
file-type "ipcoho,"
file-type "ipsteelhead,"
file-type "heightm,"
file-type "diamcm,"
file-type "sin-count,"
file-type "grad,"
file-type "size_ratio,"
file-type "stickiness,"
file-type "acw,"
file-type "vwi,"
file-type "color,"
file-print "length"
file-close 
  
end


to go
  ;;This part respawns new LWD continuously
  ;;Note that this could be improved to account for slope and other factors that increase LWD input
  ask water-patches
  [ if (random 10000 > 9998)
    [ sprout 1 [set len heightm set diameter diamcm set size 15 set shape "line" set color 15 set age 0] 
      ] ]
  
  ;This ages all of the LWD by one tick - see below
  lwd-decay
  
  ;;This is the key block of code that says if a tree stays in one place or it moves
  ask turtles [set size_ratio ( len / acw ) ] 
  ask patches [set num count turtles-here]
  ask turtles [ set stickiness ( sin-count - grad + (num / 10) + (( size_ratio + .01 ) / 20 ) ) ]
  
  
  ask turtles 
  [ ifelse (random 1000 > (stickiness * 1000) ) 
    [ move-lwd set color yellow ]
    [ set color red ] ]
  
  ask water-patches [ set heightm ( heightm + growth_rate) ]
  
  if ( ticks = 5000) [ stop export-view "view.png" ]
  
  tick  
  
  write-to-file
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;Just some helper code for debugging
to test-na
  ask patches
      [ if (ipcoho = "NaN") [ set pcolor red] ] 

end

;;Removes veg randomly based on the slider bar on the interface
to harvest
  ask patches 
     [ ifelse (random 100 < harvest_perc) 
      [ set heightm 0 set diamcm 0] 
      [ set pcolor green ] 
      ]
     ask water-patches [ set pcolor blue ] 
end


;; This would have been elegant but I seem to have too many patches - it doesnt finish in a timely manner 
to define-unique-id-patches
( foreach (sort patches) ( n-values count patches [?] )  [
  ask ?1 [ set id ?2 ]
] )
end


;; This writes out the data at every tick
;; note that this would be way more elegant as a foreach command and a list.... just saying
to write-to-file
 file-open "LWDOutput.csv" 
 ask turtles [ 
   file-type (word ticks",") ; this should be first  
   file-type (word pxcor",")
   file-type (word pycor",")   
   file-type (word id",") 
   file-type (word diameter",")
   file-type (word ipcoho",")
   file-type (word ipsteelhead",")
   file-type (word heightm ",")
   file-type (word diamcm",")
   file-type (word sin-count",")
   file-type (word grad",")
   file-type (word size_ratio",")
   file-type (word stickiness",")
   file-type (word acw",")
   file-type (word vwi",")
   file-type (word color",")
   file-print len ; note that this needs to be last
 ]
 file-close
 
end 


;; This is just a helper function that clears the board of LWD via a button on the 'Interface'
to clear-lwd
  ask turtles [die]
end

;; This function applies the vegetation GIS data to the patches
;; Id like to apply more detailed info on what kind of tree it is to the input of the LWD
to define-veg
  gis:apply-coverage vegetation-dataset "HEIGHT" heightm ; in meters - from the STNDHGT attribute in the GNN dataset
  gis:apply-coverage vegetation-dataset "DIAM" diamcm ; in centimeters
  ;;Note that I am not using the vegtype yet - but ideally it should influence decay
  gis:apply-coverage vegetation-dataset "VC_MNDBHBA" vegtype  ; Vegetation class based on CANCOV, BAH_PROP, MNDBHBA - Not used yet
  gis:apply-coverage vegetation-dataset "AGE_DOM" age
end


;; This just draws the watershed boundary without adding properties
;; Next step is to add in the shaded relief
to display-watershed
  gis:set-drawing-color black
  gis:draw watershed-dataset 3
  ;;gis:draw fp-dataset 1
end

;;This is a simple way to define the sinuosity of the stream network
to define-sincount
  set sin-count mean [water] of neighbors
  set sin-count (1 - sin-count) 
end


;;This applies the hydro data and defines the stream network
;; Note that the size of the stream in the model is based on the modeled active channel width
to define-acw
 gis:apply-coverage rivers-dataset "ID" water
 gis:apply-coverage fp-dataset "MEAN_GRAD" grad
 gis:apply-coverage fp-dataset "ACW__M_" acw
 gis:apply-coverage fp-dataset "IP_COHO" ipcoho
 gis:apply-coverage fp-dataset "IP_STEELHD" ipsteelhead
 gis:apply-coverage fp-dataset "VWI" vwi
 ask patches 
  [ ifelse (water = 1)
    [ set pcolor blue ]
    [ set pcolor white 
      set water 0] ]
end


;;Im not using this yet but it could be included in the lwd input variable
;;Note that 40% is generally a good starting place for critical slope
to define-slope
  gis:apply-coverage slope-dataset "SLOPE" slope
  ask patches
  [ if (slope > critical_slope)
  [ set pcolor yellow ] ] 
end


;; This just spawns them the first time - the respawn happens in the go procedure
;; I could either do an IFELSE (ticks = 0) for the respawn or I could write a second respawn
to spawn-lwd
  ask water-patches
  [ if (random 100 > 95)
    [ sprout 1 [set len heightm set diameter diamcm set size 15 set shape "line" set color 15 set age 0] 
      ] ]
end

;; This applies an elevation value from the 10m DEM to the patches
;; This is the foundation of the movement direction
to define-elevation
  gis:apply-coverage elevation-dataset "GRIDCODE" elevation
end


;;This just moves the wood downstream
;;Note that it appears to be scale dependent - 
;; e.g. if the world size goes to 500x500 for example some of the lower patches have the same elevation and the LWD gets stuck
to move-lwd
   move-to min-one-of neighbors [ elevation ]
end


;;;TBD should count a certain length of time based on hw con class then disapear
;; 1000 ticks is 100% arbitrary at this time - I still havent linked a tick to an actual unit of time
to lwd-decay
  ask turtles 
  [ if (age_turtle = 1000)
    [ die ]
  ]
  ask turtles [set age_turtle (age_turtle + 1)]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;







  
@#$#@#$#@
GRAPHICS-WINDOW
282
10
893
642
300
300
1.0
1
10
1
1
1
0
0
0
1
-300
300
-300
300
1
1
1
ticks
100.0

BUTTON
55
17
125
50
setup
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

SLIDER
47
112
220
145
critical_slope
critical_slope
0
100
100
1
1
NIL
HORIZONTAL

BUTTON
141
18
216
54
NIL
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
56
62
123
95
NIL
clear-lwd
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
49
155
221
188
harvest_perc
harvest_perc
0
100
52
1
1
NIL
HORIZONTAL

PLOT
907
21
1107
171
Pieces of LWD
Ticks
#Pieces
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

BUTTON
142
62
216
95
NIL
harvest
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
74
199
201
232
Reset Vegetation
define-veg
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
48
244
220
277
growth_rate
growth_rate
0
.1
0.0010
.001
1
cm
HORIZONTAL

MONITOR
1154
183
1298
228
NIL
mean [len] of turtles
1
1
11

BUTTON
88
292
177
325
NIL
reset-ticks
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1119
20
1316
170
Mean length (m) of turtles
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
"default" 1.0 0 -16777216 true "" "plot mean [len] of turtles"

BUTTON
88
335
178
368
NIL
spawn-lwd
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 5.2.0
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
