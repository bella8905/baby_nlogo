breed [A_citizens A_citizen]
breed [B_citizens B_citizen]

turtles-own[
  groupism
  resource         ; total resource = resource_private + investment
  resource_private
  investment
]
globals [
  ;
  A_resource A_strength
  B_resource B_strength

  A_d_total
  B_d_total

  A_n_total
  B_n_total

  ; conflict
  conflict_today days_after_conflict conflict_calendar

  ; border
  border_target_color border_prev_color border_color_flipped_days_passed border_color_flipped_times
]

; constants
to-report stride report 1 end  ; stride length
to-report border_color_tweening_days report 2 end
to-report border_color_flipped_times_total report 2 end
to-report border_color_conflict report [255 0 0] end
to-report border_color_neutral report [255 255 0] end
to-report conflict_cycle report 50 end

to setup
  clear-all

  ; print run

  set conflict_today false
  set days_after_conflict -1
  set conflict_calendar []
  set border_target_color border_color_neutral
  set border_prev_color border_target_color
  set border_color_flipped_days_passed -1
  set A_d_total 0
  set B_d_total 0
  set A_n_total 0
  set B_n_total 0

  ; citizen attributes
  create-A_citizens A_number_citizens [
    set xcor -1 - random 16
    set ycor random-ycor
    set shape "person"
    set groupism random-normal A_tough_loose 0.15 ; distribution of conservatism in migrant population
    set resource 1
  ]

  create-B_citizens B_number_citizens [
    set xcor 1 + random 16
    set ycor random-ycor
    set shape "person"
    set groupism random-normal B_tough_loose 0.15 ; distribution of conservatism in migrant population
    set resource 1
  ]

  citizens_color
  citizens_update
  border_color

  reset-ticks

end

to go
  if check_stop [
    stop
  ]

  if enable_conflict [
    conflict_roll_dice
    conflict_update
  ]

  if enable_reproduce [
    citizens_reproduce
  ]
  citizens_update
  citizens_move
  citizens_interact

  border_color
  ; show ticks

  tick
end

to-report check_stop
  if ticks_stop > 0 and ticks = ticks_stop  [
    report true
  ]
  report false
end

to citizens_color
  ask turtles [
    ; update citizens color
    ifelse groupism >= 0.5 [
      set color red + 2 - lerp 0 3 abs ( groupism - 0.5 ) * 2
    ][
      set color green + 1 - lerp 0 3 abs ( groupism - 0.5 ) * 2
    ]
  ]
end

to border_color
  let border_c border_color_neutral

  if border_color_flipped_days_passed >= 0 [
    let t border_color_flipped_days_passed / border_color_tweening_days
    let r1 item 0 border_prev_color
    let r2 item 0 border_target_color
    let g1 item 1 border_prev_color
    let g2 item 1 border_target_color
    let b1 item 2 border_prev_color
    let b2 item 2 border_target_color
    let rc lerp r1 r2 t
    let gc lerp g1 g2 t
    let bc lerp b1 b2 t
    set border_c (list rc gc bc)

    set border_color_flipped_days_passed border_color_flipped_days_passed + 1
    ; flip color
    if border_color_flipped_days_passed > border_color_tweening_days [
      set border_color_flipped_days_passed 0
      set border_prev_color border_target_color
      ifelse border_target_color = border_color_conflict [
        set border_target_color border_color_neutral
      ][
        set border_color_flipped_times border_color_flipped_times + 1
        if  border_color_flipped_times < border_color_flipped_times_total [
          set border_target_color border_color_conflict
        ]
      ]
    ]
  ]

  ask patches with [pxcor = 0] [set pcolor border_c]

end


to citizens_update

  ; update resource
  let A_resource_tmp 0
  ask A_citizens [
    set resource resource + 0.5
    set investment resource * ( lerp 0 0.2 groupism )
    set resource_private resource - investment
    set A_resource_tmp A_resource_tmp + investment
  ]
  set A_resource A_resource_tmp

  let B_resource_tmp 0
  ask B_citizens [
    set resource resource + 0.5
    set investment resource * ( lerp 0 0.2 groupism )
    set resource_private resource - investment
    set B_resource_tmp B_resource_tmp + investment
  ]
  set B_resource B_resource_tmp

end

to citizens_move
  ask A_citizens [
    ; randomly move
    right random-float 50
    left random-float 50
    forward stride
    ; avoid moving out of bounds
    if not is-patch? patch-ahead 1 [back stride rt 90]
    if [pxcor] of patch-here = 0 [back 1 rt 90]
  ]
  ask B_citizens [
    right random-float 50
    left random-float 50
    forward stride
    ; avoid moving out of bounds
    if not is-patch? patch-ahead 1 [back stride rt 90]
    if [pxcor] of patch-here = 0 [back 1 rt 90]
  ]
end

to citizens_interact
  ; citizens interact with other citizens in their neighborhood
  ask turtles [
    ; clear old interactions
    ask my-out-links [
      die
    ]
    ; build new interactions
    ifelse groupism >= 0.5 [
      create-links-to other turtles in-radius 1.5 with [ breed = [breed] of myself and  groupism >= 0.5 ]
    ][
      create-links-to other turtles in-radius 1.5 with [ breed = [breed] of myself ]
    ]
    ask my-out-links [
      set color grey
    ]
  ]
end

to conflict
  if count A_citizens > 0 and count B_citizens > 0 [
    set conflict_today true
    set days_after_conflict 0
    set border_target_color border_color_conflict
    set border_color_flipped_days_passed 0
    set border_color_flipped_times 0

    set A_strength 0.01 * (sum [resource_private] of A_citizens) + 0.1 * A_resource
    set B_strength 0.01 * (sum [resource_private] of B_citizens) + 0.1 * B_resource

    print (word "day " ticks ": conflicts happen! A_strength: " A_strength " B_strength: " B_strength )

    let A_d 0
    let B_d 0
    ifelse A_strength > B_strength [
      let r A_strength / B_strength
      ifelse r < 1.25 [
        set A_d 0.45 * count A_citizens
        set B_d 0.1 * count B_citizens
      ] [
        ifelse r >= 2 [
          set B_d 0.5 * count B_citizens
        ] [
          set A_d 0.05 * count A_citizens
          set B_d 0.25 * count B_citizens
        ]
      ]
    ] [
      if A_strength < B_strength [
        let r B_strength / A_strength
        ifelse r < 1.25 [
          set B_d 0.45 * count B_citizens
          set A_d 0.1 * count A_citizens
        ] [
          ifelse r >= 2 [
            set A_d 0.5 * count A_citizens
          ] [
            set B_d 0.05 * count B_citizens
            set A_d 0.25 * count A_citizens
          ]
        ]
      ]
    ]

    ; remove citizens based on A_d and B_d
    citizens_random_kill A_citizens A_d
    citizens_random_kill B_citizens B_d
  ]
end

to citizens_reproduce
  let A_new_baby_count 0
  let B_new_baby_count 0
  ask turtles with [resource_private > 50] [
    set resource_private resource_private * 0.5
    set resource resource_private + investment
    ; let resource_kid resource
    hatch 1 [
      ; inherit resource_private from parent, and investment = 0
      set resource resource_private
      set groupism random-float 1
      ifelse breed = A_citizens [
        set A_new_baby_count A_new_baby_count + 1
        set A_n_total A_n_total + 1
      ] [
        set B_new_baby_count B_new_baby_count + 1
        set B_n_total B_n_total + 1
      ]
    ]
  ]

  if A_new_baby_count > 0 [
    print (word "day " ticks ": " A_new_baby_count " new A babies are born! " )
  ]
  if B_new_baby_count > 0 [
    print (word "day " ticks ": " B_new_baby_count " new B babies are born! " )
  ]
end

; create conflict_calendar with randomly picked days
to conflict_roll_dice
  if ticks mod conflict_cycle = 0 [
    set conflict_calendar n-values conflict_count_per_cycle [(random conflict_cycle) + ticks]

    print (word "day " ticks ": refresh conflict calendar: " conflict_calendar )
  ]
end

to conflict_update
  if member? ticks conflict_calendar [
    ; show ticks
    conflict
  ]
end

; https://jonlabelle.com/snippets/view/csharp/pick-random-elements-based-on-probability
; to-report citizens_random_kill_one_by_groupism [citizens]
;  let citizen_killed false
;  ifelse count citizens > 0 [
;    let groupism_total sum [groupism] of citizens
;    let dice_roll random-float 1
;    let groupism_normalized_cumulative 0
;    let stop_loop false     ; stop doesn't do the trick in ask as I tried it..
;    ask citizens [
;      if stop_loop = false [
;        let groupism_normalized groupism / groupism_total
;        set groupism_normalized_cumulative groupism_normalized_cumulative + groupism_normalized
;        if groupism_normalized_cumulative > dice_roll [
;          ; print (word "day " ticks ": killed a " breed " with groupism " groupism ",at " dice_roll )
;          set stop_loop true
;          set citizen_killed true
;          die
;        ]
;      ]
;    ]
;  ] [
;    print (word "day " ticks ":all citizens have been killed" )
;  ]
;
;  report citizen_killed
; end

to-report citizens_random_kill_one_by_groupism [citizens]
  let citizen_killed false
  ifelse count citizens > 0 [
    let groupism_inv_total 0
    ask citizens [
      set groupism_inv_total groupism_inv_total + ( 1.0 - groupism )
    ]

    let dice_roll random-float 1
    let groupism_inv_normalized_cumulative 0
    let stop_loop false     ; stop doesn't do the trick in ask as I tried it..
    ask citizens [
      if stop_loop = false [
        let groupism_inv_normalized ( 1.0 - groupism ) / groupism_inv_total
        set groupism_inv_normalized_cumulative groupism_inv_normalized_cumulative + groupism_inv_normalized
        if groupism_inv_normalized_cumulative > dice_roll [
          ; print (word "day " ticks ": killed a " breed " with groupism " groupism ",at " dice_roll )
          set stop_loop true
          set citizen_killed true
          die
        ]
      ]
    ]
  ] [
    print (word "day " ticks ":all citizens have been killed" )
  ]

  report citizen_killed
end



to citizens_random_kill [citizens num_to_kill]
  let num_killed 0
  let citizen_type [breed] of one-of citizens

  while [num_to_kill > 0] [
    let killed citizens_random_kill_one_by_groupism citizens
    if killed = true [
      set num_killed num_killed + 1
    ]
    set num_to_kill num_to_kill - 1
  ]

  if num_killed > 0 [
    print (word "day " ticks ": " num_killed " " citizen_type " have been killed" )
    ifelse citizen_type = A_citizens [
      set A_d_total A_d_total + num_killed
    ][
      set B_d_total B_d_total + num_killed
    ]
  ]
end

; utility functions
;
; linear interpolation
; a: start
; b: end
; s: step
to-report lerp [a0 a1 s]
  report a0 + ( a1 - a0 ) * s
end
@#$#@#$#@
GRAPHICS-WINDOW
292
29
805
543
-1
-1
15.303030303030303
1
10
1
1
1
0
0
0
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
218
467
284
500
NIL
Setup
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
218
507
285
540
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
50
83
251
116
A_tough_loose
A_tough_loose
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
53
249
254
282
B_tough_loose
B_tough_loose
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
49
44
251
77
A_number_citizens
A_number_citizens
0
500
150.0
1
1
NIL
HORIZONTAL

SLIDER
53
286
255
319
B_number_citizens
B_number_citizens
0
500
150.0
1
1
NIL
HORIZONTAL

MONITOR
69
181
147
226
A_resource
A_resource
2
1
11

MONITOR
68
387
148
432
B_resource
B_resource
2
1
11

MONITOR
158
181
238
226
m_A_con
mean [groupism] of A_citizens
2
1
11

MONITOR
157
388
236
433
m_B_com
mean [groupism] of B_citizens
2
1
11

SLIDER
819
112
911
145
conflict_count_per_cycle
conflict_count_per_cycle
0
10
2.0
1
1
NIL
HORIZONTAL

MONITOR
819
152
1008
197
threat_calendar
conflict_calendar
17
1
11

SLIDER
915
112
1007
145
b
b
0
1
0.23
0.01
1
NIL
HORIZONTAL

SWITCH
819
31
1007
64
enable_conflict
enable_conflict
0
1
-1000

SWITCH
819
71
1007
104
enable_reproduce
enable_reproduce
0
1
-1000

MONITOR
1082
216
1204
261
current_A_citizens
count A_citizens
0
1
11

MONITOR
1085
382
1205
427
current_B_citizens
count B_citizens
0
1
11

MONITOR
69
127
148
172
%_A_con
( count A_citizens with [groupism >= 0.5] ) / count A_citizens * 100
2
1
11

MONITOR
69
330
148
375
%_B_con
( count B_citizens with [groupism >= 0.5] ) / count B_citizens * 100
2
1
11

MONITOR
157
127
237
172
%_A_lib
( count A_citizens with [groupism < 0.5] ) / count A_citizens * 100
2
1
11

MONITOR
157
331
236
376
%_B_liberal
( count B_citizens with [groupism < 0.5] ) / count B_citizens * 100
2
1
11

MONITOR
1083
266
1142
311
NIL
A_d_total
17
1
11

MONITOR
1086
433
1144
478
NIL
B_d_total
17
1
11

MONITOR
1145
266
1203
311
NIL
A_n_total
17
1
11

MONITOR
1147
433
1205
478
NIL
B_n_total
17
1
11

PLOT
819
216
1071
372
A Society
time
suviving rate
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"A_lib" 1.0 0 -13840069 true "" "plot count ( A_citizens with [ groupism < 0.5 ] ) / count A_citizens\n"
"B_con" 1.0 0 -2674135 true "" "plot count ( A_citizens with [ groupism >= 0.5 ] ) / count A_citizens\n"

PLOT
820
382
1073
543
B Society
time
suviving rate
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"B_lib" 1.0 0 -13840069 true "" "plot count ( B_citizens with [ groupism < 0.5 ] ) / count B_citizens"
"B_con" 1.0 0 -2674135 true "" "plot count ( B_citizens with [ groupism >= 0.5 ] ) / count B_citizens"

MONITOR
1262
31
1383
76
global conservatism
sum [ groupism >= 0.5 ] of turtles
2
1
11

PLOT
1019
31
1246
196
global environment
time
suviving rate
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"num-lib" 1.0 0 -13840069 true "" "plot count ( turtles with [ groupism < 0.5 ] ) / count turtles\n"
"num_con" 1.0 0 -2674135 true "" "plot count ( turtles with [ groupism >= 0.5 ] ) / count turtles"

INPUTBOX
215
554
364
614
ticks_stop
300.0
1
0
Number

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
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="ticks_stop">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable_conflict">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="A_number_citizens">
      <value value="150"/>
      <value value="250"/>
      <value value="350"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="conflict_count_per_cycle">
      <value value="0"/>
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable_reproduce">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="A_tough_loose">
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.23"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="B_tough_loose">
      <value value="0.3"/>
      <value value="0.5"/>
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="B_number_citizens">
      <value value="150"/>
      <value value="250"/>
      <value value="350"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>check_stop</exitCondition>
    <metric>count A_citizens</metric>
    <metric>count B_citizens</metric>
    <enumeratedValueSet variable="ticks_stop">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable_conflict">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="A_number_citizens">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="conflict_count_per_cycle">
      <value value="2"/>
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="enable_reproduce">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="A_tough_loose">
      <value value="0.3"/>
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="b">
      <value value="0.23"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="B_tough_loose">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="B_number_citizens">
      <value value="150"/>
      <value value="250"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
Line -7500403 true 150 60 120 120
Line -7500403 true 150 60 180 120
@#$#@#$#@
0
@#$#@#$#@
