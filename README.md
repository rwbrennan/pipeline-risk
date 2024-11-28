## PIPELINE RISK MODEL

This model simulates raifall over a geographic area. The intention is to determine the risk of infrastructure damage (in this case, an energy pipeline) resulting from adverse weather conditions. The ultimate goal is to identify risk at points along a pipeline for various weather conditions.

## HOW IT WORKS

The model loads a digtial elevation model (DEM) in ASCII .asc format on _Setup_. The DEM can be prepared using [QGIS](https://www.qgis.org/) and the [OpenTopography DEM](https://opentopography.org/) plugin. The worldview is adjusted during setup based on the size of the DEM (i.e., number of columns and rows in the .asc file).

On _Setup_ a text file is read to load the pipeline and storm cell data. The format of the file is as follows:

```
<pxcor of start of pipeline> <pycor of start of pipeline>
<pxcor of end of pipeline> <pycor of end of pipeline>
<number of pipeline sensors>
<cell-mean-x> <cell-sd-x> <cell-mean-y> <cell-sd-y> <cell-rain-rate> <cell-speed> <cell-heading>
```

The _Go_ routine creates raindrops at random locations at the specified _rain-rate_. Raindrops flow downstream based on the slope of the landscape (determined by the DEM). 

## HOW TO USE IT

The model includes the following options:

* _Setup_ Button: loads the DEM and the pipeline data.
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
    * _sensor_ turtles have been added as sensing points along the pipeline (connected by links)
    * currently, only a straight pipeline section can be specified; it would be helpful to be able to specify bends in the pipeline (see the APPL pipeline in Google Earth)
  * Rainfall:
    * a weather pattern moves through the geographic area by having the rainfall occur around a centroid (i.e., the centre of the weather pattern)
    * could multiple storm cells be added (this will likely mean changing the centroid parameters from global to local (to the cell type)
  * Experiments:
    * each experiment would generate a data point for a given weather condition
    * multiple experiments across a range of parameters would create a database for an ML model
    * this database could cover the entire pipleine (for now we are just looking at one section of the APPL line)

## IDEAS

### Weather Pattern

Try multiple storm cells.

## NETLOGO FEATURES

This model uses the [Netlogo GIS extension](https://ccl.northwestern.edu/netlogo/docs/gis.html).

## RELATED MODELS

This model uses features of the _Grand Canyon_ model and the _GIS Gradient Example_ model from the Netlogo Models Library.

## CREDITS AND REFERENCES

Copyright 2024 Robert W. Brennan.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons Licence" style="border-width:0" src="https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
<!-- 2024 -->