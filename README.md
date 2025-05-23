## PIPELINE RISK MODEL

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
* _deg-min-sec?_ Button: allows the user to choose the format for the _cell_ and _sensor_ coordinate labels (i.e., between degree-minutes-seconds and decimal format).
* _draw?_ Selector: draws the path of each raindrop.
* _inspect-sensor_ Selector: allows the user to select the `inspect sensor` feature; when selected, a window opens showing the details the sensor that is selected (clicked on).
* _Flow_ Plot: this plot shows the current number of raindrops around the sensor (a rough indicator of the current flow of water at the sensing point); different sensing locations can be selected by clicking on a pipeline sensor; when selected, the sensor changes from yellow to red and the Rainfall plot shows data at the sensor point.
* _Rainfall_ Plot: this plot shows the total amount of rainfall (raindrops) in the worldview

## EXTENDING THE MODEL

Ultimately, the model will be used to generate a database of rainfall cases for various weather parameters. The input parameters could be similar to what one would obtain from a weather forcast (e.g., storm direction, speed, intensity, etc.). The output parameters will be taken at various points along the pipeline and will relate to risk of pipeline failure (most likely maximum flow rate at the point). 

The plan for model extension is as follows:

  * Pipeline: 
    * currently, only a straight pipeline section can be specified; it would be helpful to be able to specify bends in the pipeline (see the APPL pipeline in _Google Earth_)
    * it would be interesting to have the _sensor_ nodes change in appearance based on the flow at the sensor; this could be a change in colour and/or size of the sensor point
  * Weather Pattern:
    * a single weather pattern moves through the geographic area by having the rainfall occur around a centroid (i.e., the centre of the weather pattern)
    * could multiple storm cells be added (this will likely require the centroid parameters to be moved from global to local (to the cell type) or changed to a list; as well as some changes to the code to reflect this
    * additionally, the storm cells should grow/diminish in intensity over time
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

The following is a list of next steps (not prioritized):


  * convert input .txt to latitude-longitude coordinates
    * properly located (based on _Google Earth_ information)
    * update so that changes in direction are possible (not just a straight line)
  * scaling
    * specify the storm cell speed in m/s (or km/hr) - check Environment Canada to see how weather patterns are specified
    * specify the rainwater flow rate in m/s (also determine typical rainwater flow rates and adjust accordingly)
    * create a procedure to update rainwater flow rate based on gradient (change in elevation) or slope
  * modeling enhancements
    * update the model to allow for multiple storm cells
    * create some animation (colour and/or size) to indicate water flow at each sensor

## IDEAS

### Multiple Storm Cells

As noted above, the option for multiple storm cells should be added. From an input data perspective, this could just be a matter of adding extra storm cell lines to the input data file.

### Storm Cell at Boundary

When the storm centroid reaches the boundary, the current model decreases the rain rate by 10% at each step (i.e., based on the cell centroid speed). This is not quite right as the size of the cell (within the boundaries) is also decreasing. The current approach is likely a good approximation, though it would be worthwhile to investigate this part of the model more closely.

### Storm Cell Intensity

The storm cell(s) should increase and/or diminish in intensity over time. 

### Digital Elevation Model (DEM)

The current DEM from Open Topography is 30 m resolution. It would be useful to use a higher resolution DEM (obtained from U Calgary resources).

### Data Collection

Data needs to be collected at each of the sensor points. For example:

  * location of sensor: currently this can be obtained directly from the DEM
  * water flow: current flow, maximum flow, flow profile

### Specifying the Pipeline

Currently, the pipeline is specified by a start and end point, then the sensors are placed evenly between the points in a straight line. Here are some ideas on how to specify the pipeline with changes in direction. It would be worthwhile to try to write the procedure for this in a new file, then porting the results to this file.

  * The input file could specify the inital coordinates of the _locating sensors_ (sensors at the start, finish, and each point where there is a change in direction).
  * Rather than specifying the number of sensors, specify the distance, _d_, between sensors (e.g., in metres).
  * Add a new sensor every _d_ metres along the straight line connecting the sensors.
  * If the distance to the next sensor, _l_, is < _d_, stop (then go to the next _locating sensor_)

The input file would look something like the following: 

[ _n_ ] [ _d_ ]
[ _lat<sub>1</sub>_ ] [ _long<sub>1</sub>_ ] 
[ _lat<sub>2</sub>_ ] [ _long<sub>2</sub>_ ] 
... ...
... ...
[ _lat<sub>n</sub>_ ] [ _long<sub>n</sub>_ ] 


where:

_n_ = number of locating sensors
_d_ = distance between sensors
_lat<sub>i</sub>_ = latitude of locating sensor _i_
_long<sub>i</sub>_ = longitude of locating sensor _i_

## NETLOGO FEATURES

This model uses the [Netlogo GIS extension](https://ccl.northwestern.edu/netlogo/docs/gis.html).

## RELATED MODELS

This model uses features of the _Grand Canyon_ model and the _GIS Gradient Example_ model from the Netlogo Models Library.

## CREDITS AND REFERENCES

Copyright 2024 Robert W. Brennan.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons Licence" style="border-width:0" src="https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
<!-- 2024 -->