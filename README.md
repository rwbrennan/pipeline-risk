## PIPELINE RISK MODEL

This model simulates raifall over a geographic area. The intention is to determine the risk of infrastructure damage (in this case, energy pipelines) resulting from adverse weather conditions. The ultimate goal is to identify risk at points along a pipeline for various weather conditions.

## HOW IT WORKS

The model loads a digtial elevation model (DEM) in ASCII .asc format on setup. The DEM can be prepared using [QGIS](https://www.qgis.org/) and the [OpenTopography DEM](https://opentopography.org/) plugin. The worldview is adjusted during setup based on the size of the DEM (i.e., number of columns and rows in the .asc file).

The _Go_ routine creates raindrops at random locations at the specified _rain-rate_. Raindrops flow downstream based on the slope of the landscape (determined by the DEM). 

A pipeline with sensing points is added to the model worldview by reading the start and end points and number of sensing points from a text file. The sensing points will be used to determine water flowrate at various points along the pipeline. 

## HOW TO USE IT

The model includes the following options:

* _Setup_ Button: loads the DEM.
* _Go_ Button: creates raindrops at the specified _rain-rate_.
* _Display Elevation_ Button: renders the worldview by elevation (This is the default view).
* _Display Slope_ Button: renders the worldview by slope (rate of change of elevation for each DEM pixel).  
* _Display Aspect_ Button: renders the worldview by aspect (slope direction).
* _draw?_ Selector: draws the path of each raindrop.
* _rain-rate_ Selector: allows the user to select the rain rate in drops/tick.  
* _Rainfall_ Plot: this plot shows the current number of raindrops around the sensor (a rough indicator of the current flow of water at the sensing point); different sensing locations can be selected by clicking on a pipeline sensor; when selected, the sensor changes from yellow to red and the Rainfall plot shows data at the sensor point.

## EXTENDING THE MODEL

Ultimately, the model will be used to generate a database of rainfall cases for various weather parameters. The input parameters could be similar to what one would obtain from a weather forcast (e.g., storm direction, speed, intensity, etc.). The output parameters would be taken at various points along the pipeline and would relate to risk of pipeline failure (most likely maximum flow rate at the point). 

The plan for model extension is as follows:

  * Pipeline: 
    * sensor turtles have been added as sensing points along the pipeline (connected by links)
    * currently, only a straight pipeline section can be specified; it would be helpful to be able to specify bends in the pipeline (see the APPL pipeline in Google Earth)
  * Rainfall:
    * rather than random rainfall across the map, random around a centroid
    * move the centroid (to simulate the storm moving through)
    * it would be nice to show the centroid on the map (as it moves)
  * Experiments:
    * each experiment would generate a data point for a given weather condition
    * multiple experiments across a range of parameters would create a database for an ML model
    * this database could cover the entire pipleine (for now we are just looking at one section of the APPL line)

## IDEAS

Change the `move-to one-of patches` command when creating raindrops to a centroid.

```
move-to patch random-normal mean-pxcor stddev-pxcor random-normal mean-pycor stddev-pycor
```

The `max-pxcor` and `max-pycor` could be used to determine where the centroil (i.e., the means) are located. The standard deviation could be related to the size of the storm.

## NETLOGO FEATURES

This model uses the [Netlogo GIS extension](https://ccl.northwestern.edu/netlogo/docs/gis.html).

## RELATED MODELS

This model uses features of the _Grand Canyon_ model and the _GIS Gradient Example_ model from the Netlogo Models Library.

## CREDITS AND REFERENCES

Copyright 2024 Robert W. Brennan.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons Licence" style="border-width:0" src="https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
<!-- 2024 -->