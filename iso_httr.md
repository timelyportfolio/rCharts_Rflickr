---
title       : Flickr Interesting ISOs with Rflickr & rCharts
author: Timely Portfolio
github: {user: timelyportfolio, repo: rCharts_Rflickr, branch: "gh-pages"}
framework: bootstrap
mode: selfcontained
highlighter: prettify
hitheme: twitter-bootstrap
assets:
  css:
  - "http://fonts.googleapis.com/css?family=Raleway:300"
  - "http://fonts.googleapis.com/css?family=Oxygen"
---
  
<style>
iframe{
  height:450px;
  width:900px;
  margin:auto auto;
}

body{
  font-family: 'Oxygen', sans-serif;
  font-size: 16px;
  line-height: 24px;
}

h1,h2,h3,h4 {
  font-family: 'Raleway', sans-serif;
}

.container { width: 900px; }

h3 {
  background-color: #D4DAEC;
    text-indent: 100px; 
}

h4 {
  text-indent: 100px;
}

iframe {height: 420px; width: 620px}
</style>
  
<a href="https://github.com/timelyportfolio/rCharts_Rflickr"><img style="position: absolute; top: 0; right: 0; border: 0;" src="https://s3.amazonaws.com/github/ribbons/forkme_right_darkblue_121621.png" alt="Fork me on GitHub"></a>

<div class = "hero-unit">
<h1> Flickr Interesting ISOs with httr & rCharts + slidify </h1>



<p>
I have rewritten <a href = "http://timelyportfolio.blogspot.com/2013/10/iso-popularity-on-flickr-explore.html">this old post</a> to use Hadley Wickham's <a href = "http://github.com/hadley/httr"><code>httr</code> </a> instead of <code>Rflickr</code> for two reasons:
</p>

<ol>
  <li>
    <code>Rflickr</code> is not working for me anymore
  </li>
  <li>
    <code>httr</code> is a very helpful package for navigating the "what was scary to me" world of http and oauth
  </li>
</ol>

<p>
In addition to the changes above, I will also demonstrate use of the <a href = "http://renkun.me/blog/2014/07/26/difference-between-magrittr-and-pipeR.html"><code>pipeR</code></a> package from <a href = "http://renkun.me/">Kun Ren</a> who has been quite prolific lately.  I feel pretty strongly I will be rewriting this post one more time in the near future employing his <a href ="http://renkun.me/blog/2014/06/26/rlist-a-new-package-for-working-with-list-objects-in-r.html"><code>rlist</code></a> package.
</p>

<p>
I will incorporate the original text into the content below.
</p>
</div>


The information available from [the Flickr API](http://www.flickr.com/services/api/) is incredibly rich.  This Atlantic article [This is the World on Flickr](http://www.theatlantic.com/technology/archive/2013/10/this-is-the-world-on-flickr/280697/) motivated me to open up R and do some analysis on the [Flickr Explore](http://www.flickr.com/explore) list.  As you might expect, I'll be using my new favorite tools [`rCharts`](http://rcharts.io) and [`slidify`](http://slidify.org).

### ISO Speed Popularity
I have always wondered what ISO speeds occur most frequently on Explore.  I never imagined that I could answer my question with R.  As usual, we will start by loading all the necessary packages.

<h5>Load Our Packages</h5>

```r
# analyze EXIF data for interesting list
library(httr)
library(pipeR)
library(jsonlite)
```

If you do not have a free noncommercial API key, apply for one [here](http://www.flickr.com/services/api/keys/).  Trust me it is very easy, so don't let this be an excuse not to try it out.  I put mine in a little `secrets.Rdata` file that I will load with following code and then start a session.

<h5>Authorize Our flickr</h5>


```r
load("secrets.Rdata")

flickr.app <- oauth_app("r to flickr",api_key,secret)
flickr.endpoint <- oauth_endpoint(
  request = "https://www.flickr.com/services/oauth/request_token"
  , authorize = "https://www.flickr.com/services/oauth/authorize"
  , access = "https://www.flickr.com/services/oauth/access_token"
)

tok <- oauth1.0_token(
  flickr.endpoint
  , flickr.app
  , cache = F
)
```

Since this is more a proof of concept rather than an ambitious scientific study, I'll just look back three days.


```r
#use this to specify how many days to analyze
daysAnalyze = 3
```

My code gets a little sloppy here but it does work.  Originally I was forced to use a whole lot of `lapply`, but `httr` plays nicely with JSON, and `jsonlite` converts it to traditional R data stuctures.  I hope my comments will help you understand each of the steps.

<h5>Get the Interesting</h5>

This will give us a list `interesting` with about 100 photos for each day.  We could get up to 500 per day if we are ambitious with the [per page](https://www.flickr.com/services/api/flickr.interestingness.getList.htm) API option.


```r
#get a list and then make it a data frame 
interesting <- lapply(1:daysAnalyze, function(i){
    GET(url=sprintf(
      "https://api.flickr.com/services/rest/?method=flickr.interestingness.getList&api_key=%s&date=%s&format=json&nojsoncallback=1"
      , api_key
      , format( Sys.Date() - i, "%Y-%m-%d")
      , tok$credentials$oauth_token
      )
    ) %>>%
      content( as = "text" ) %>>%
      jsonlite::fromJSON () %:>%
      .$photos$photo %:>%
      data.frame(
        date = format( Sys.Date() - i, "%Y-%m-%d")
        ,.
        ,stringsAsFactors=F
      ) %>>%
      return
  }
) %:>%
  # combine all the days into a data frame
  do.call(rbind, .)
```

<h5>Get EXIF for the Interesting</h5>

Now that we have some interesting photos, we can use [flickr.photos.getExif](https://www.flickr.com/services/api/flickr.photos.getExif.html) for all sorts of meta information embedded in the EXIF.


```r
  #for each photo try to get the exif information
  #Flickr allows users to block EXIF
  #so use try to bypass error
  #in case you are wondering, yes we could use dplyr here
  exifData <- lapply(
    1:nrow(interesting)
    ,function(photo){  # now we will process each photo
      exif <-
        GET(url=sprintf(
          "https://api.flickr.com/services/rest/?method=flickr.photos.getExif&api_key=%s&photo_id=%s&secret=%s&format=json&nojsoncallback=1"
          , api_key
          , interesting[photo,"id"]
          , interesting[photo,"secret"]
          )
        ) %>>%
          content( as = "text" ) %>>%
          jsonlite::fromJSON ()
    }
  )# %>>% could chain it, but want to keep exifData

  #now that we have a list of EXIF for each photo
  #use another lapply
  #to extract the useful information
  iso <- exifData %:>% 
    lapply(
      1:length(.)
      ,function(photo){
        # some photos will not have exif if their owners disable it
        # and the api call will give us a stat "fail" instead of "ok"
        ifelse ( 
          exifData[[photo]]$stat == "ok" 
          ,exifData[[photo]]$photo$exif[
            which(exifData[[photo]]$photo$exif[,"label"]=="ISO Speed"),"raw"
          ] %>>%
            as.numeric
          ,NA
        ) %:>%
        data.frame(
          interesting[photo,c("date","id")]
          ,"iso" = .
        ) %>>%
        return
      }
    ) %:>%
    do.call(rbind,.) %:>%
    with(
      .
      ,table(date,iso)
    ) %>>%
    data.frame( stringsAsFactors = F)
```


### Plot Our Results

Now that we have a `data.frame` with ISO speeds, let's use `rCharts` to analyze it.  I will use [`dimplejs`](http://dimplejs.org).



```r
# Thanks to http://tradeblotter.wordpress.com/
# Qualitative color schemes by Paul Tol
tol4qualitative=c("#4477AA", "#117733", "#DDCC77", "#CC6677")

require(rCharts)
iso %:>% dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = .,
  type = "bar",
  height = 400,
  width =600
  ,xAxis = list( orderRule = sort( .$iso ) )
  ,defaultColors = tol4qualitative
) %:>% .$show("inline")
```


<div id = 'chart2bb01c11340d' class = 'rChart dimple'></div>
<script>
var chart2bb01c11340d = (function() {
  var opts = {
 "dom": "chart2bb01c11340d",
"width":    600,
"height":    400,
"xAxis": {
 "type": "addCategoryAxis",
"showPercent": false,
"orderRule": [ "0", "0", "0", "40", "40", "40", "50", "50", "50", "64", "64", "64", "80", "80", "80", "100", "100", "100", "125", "125", "125", "160", "160", "160", "200", "200", "200", "250", "250", "250", "320", "320", "320", "400", "400", "400", "500", "500", "500", "560", "560", "560", "640", "640", "640", "800", "800", "800", "1000", "1000", "1000", "1250", "1250", "1250", "1600", "1600", "1600", "2500", "2500", "2500", "2800", "2800", "2800", "3200", "3200", "3200" ] 
},
"yAxis": {
 "type": "addMeasureAxis",
"showPercent": false 
},
"zAxis": [],
"colorAxis": [],
"defaultColors": [ "#4477AA", "#117733", "#DDCC77", "#CC6677" ],
"layers": [],
"legend": [],
"x": "iso",
"y": "Freq",
"groups": "date",
"type": "bar",
"id": "chart2bb01c11340d" 
},
    data = [{"date":"2014-07-27","iso":"0","Freq":1},{"date":"2014-07-28","iso":"0","Freq":1},{"date":"2014-07-29","iso":"0","Freq":1},{"date":"2014-07-27","iso":"40","Freq":0},{"date":"2014-07-28","iso":"40","Freq":0},{"date":"2014-07-29","iso":"40","Freq":1},{"date":"2014-07-27","iso":"50","Freq":2},{"date":"2014-07-28","iso":"50","Freq":1},{"date":"2014-07-29","iso":"50","Freq":1},{"date":"2014-07-27","iso":"64","Freq":3},{"date":"2014-07-28","iso":"64","Freq":0},{"date":"2014-07-29","iso":"64","Freq":0},{"date":"2014-07-27","iso":"80","Freq":2},{"date":"2014-07-28","iso":"80","Freq":4},{"date":"2014-07-29","iso":"80","Freq":1},{"date":"2014-07-27","iso":"100","Freq":18},{"date":"2014-07-28","iso":"100","Freq":21},{"date":"2014-07-29","iso":"100","Freq":21},{"date":"2014-07-27","iso":"125","Freq":4},{"date":"2014-07-28","iso":"125","Freq":0},{"date":"2014-07-29","iso":"125","Freq":2},{"date":"2014-07-27","iso":"160","Freq":3},{"date":"2014-07-28","iso":"160","Freq":2},{"date":"2014-07-29","iso":"160","Freq":6},{"date":"2014-07-27","iso":"200","Freq":17},{"date":"2014-07-28","iso":"200","Freq":16},{"date":"2014-07-29","iso":"200","Freq":15},{"date":"2014-07-27","iso":"250","Freq":5},{"date":"2014-07-28","iso":"250","Freq":4},{"date":"2014-07-29","iso":"250","Freq":1},{"date":"2014-07-27","iso":"320","Freq":1},{"date":"2014-07-28","iso":"320","Freq":4},{"date":"2014-07-29","iso":"320","Freq":2},{"date":"2014-07-27","iso":"400","Freq":8},{"date":"2014-07-28","iso":"400","Freq":2},{"date":"2014-07-29","iso":"400","Freq":8},{"date":"2014-07-27","iso":"500","Freq":0},{"date":"2014-07-28","iso":"500","Freq":2},{"date":"2014-07-29","iso":"500","Freq":1},{"date":"2014-07-27","iso":"560","Freq":1},{"date":"2014-07-28","iso":"560","Freq":0},{"date":"2014-07-29","iso":"560","Freq":1},{"date":"2014-07-27","iso":"640","Freq":0},{"date":"2014-07-28","iso":"640","Freq":1},{"date":"2014-07-29","iso":"640","Freq":0},{"date":"2014-07-27","iso":"800","Freq":1},{"date":"2014-07-28","iso":"800","Freq":1},{"date":"2014-07-29","iso":"800","Freq":3},{"date":"2014-07-27","iso":"1000","Freq":2},{"date":"2014-07-28","iso":"1000","Freq":1},{"date":"2014-07-29","iso":"1000","Freq":1},{"date":"2014-07-27","iso":"1250","Freq":1},{"date":"2014-07-28","iso":"1250","Freq":1},{"date":"2014-07-29","iso":"1250","Freq":1},{"date":"2014-07-27","iso":"1600","Freq":1},{"date":"2014-07-28","iso":"1600","Freq":1},{"date":"2014-07-29","iso":"1600","Freq":1},{"date":"2014-07-27","iso":"2500","Freq":0},{"date":"2014-07-28","iso":"2500","Freq":0},{"date":"2014-07-29","iso":"2500","Freq":1},{"date":"2014-07-27","iso":"2800","Freq":0},{"date":"2014-07-28","iso":"2800","Freq":1},{"date":"2014-07-29","iso":"2800","Freq":0},{"date":"2014-07-27","iso":"3200","Freq":1},{"date":"2014-07-28","iso":"3200","Freq":1},{"date":"2014-07-29","iso":"3200","Freq":0}];
  
  return drawChart(opts,data);
  
  function drawChart(opts, data){ 
    var subCharts = [];
    
    var c = null;
    var assignedColors = {};
    
      //move this to top or make function since duplicated
    //allow manipulation of default colors to use with dimple
    if(opts.defaultColors.length) {
      defaultColorsArray = [];
      if (typeof(opts.defaultColors) == "function") {
        //assume this is a d3 scale
        //if there is a domain for the color scale given
        //then we will need to assign colors with dimples assignColor
        if( opts.defaultColors.domain().length > 0 ){
          defaultColorsArray = opts.defaultColors.range();
          opts.defaultColors.domain().forEach( function( d, i ) {
            assignedColors[d] = new dimple.color(opts.defaultColors.range()[i])
          })
        } else {
          for (var n=0;n<opts.defaultColors.range().length;n++) {
            defaultColorsArray.push(opts.defaultColors(n));
          };
        }
      } else {
        defaultColorsArray = opts.defaultColors;
      }
  
      
      //if colors not assigned with no keys and opts.groups
      if (!(Object.keys(assignedColors).length) & Boolean(opts.groups)) {
        //let's just assign colors in order with each unique
        //this is important if facetting where need colors assigned
        //if not in all pairs
        opts.groups = (typeof opts.groups == "string") ? [opts.groups] : opts.groups;
        d3.set(
          data.map(function(d){
            //dimple colors by last item in groups
            return d[opts.groups[opts.groups.length-1]]
          })
        ).values().forEach(function(u,i){
          //u will be our uniqe and will pick color from defaultColorsArray
          //console.log([u,defaultColorsArray[i]].concat());
          assignedColors[u] = new dimple.color(defaultColorsArray[i % defaultColorsArray.length])
        })
      }
    }
  
    
    //do series
    //set up a function since same for each
    //as of now we have x,y,groups,data,type in opts for primary layer
    //and other layers reside in opts.layers
    function buildSeries(layer, hidden, myChart){
      //inherit from primary layer if not intentionally changed or xAxis, yAxis, zAxis null
      if (!layer.xAxis) layer.xAxis = opts.xAxis;    
      if (!layer.yAxis) layer.yAxis = opts.yAxis;
      if (!layer.zAxis) layer.zAxis = opts.zAxis;
      
      var x = buildAxis("x", layer, myChart);
      x.hidden = hidden;
      
      var y = buildAxis("y", layer, myChart);
      y.hidden = hidden;
      
      //z for bubbles
      var z = null;
      if (!(typeof(layer.zAxis) === 'undefined') && layer.zAxis.type){
        z = buildAxis("z", layer, myChart);
      };
      
      //here think I need to evaluate group and if missing do null
      //as the group argument
      //if provided need to use groups from layer
      var s = new dimple.series(myChart, null, x, y, z, c, dimple.plot[layer.type], dimple.aggregateMethod.avg, dimple.plot[layer.type].stacked);
      
      //as of v1.1.4 dimple can use different dataset for each series
      if(layer.data){
        //convert to an array of objects
        var tempdata;
        //avoid lodash for now
        datakeys = d3.keys(layer.data)
        tempdata = layer.data[datakeys[1]].map(function(d,i){
          var tempobj = {}
          datakeys.forEach(function(key){
            tempobj[key] = layer.data[key][i]
          })
          return tempobj
        })
        s.data = tempdata;
      }
      
      if(layer.hasOwnProperty("groups")) {
        s.categoryFields = (typeof layer.groups === "object") ? layer.groups : [layer.groups];
        //series offers an aggregate method that we will also need to check if available
        //options available are avg, count, max, min, sum
      }
      if (!(typeof(layer.aggregate) === 'undefined')) {
        s.aggregate = eval(layer.aggregate);
      }
      if (!(typeof(layer.lineWeight) === 'undefined')) {
        s.lineWeight = layer.lineWeight;
      }
      if (!(typeof(layer.barGap) === 'undefined')) {
        s.barGap = layer.barGap;
      }    
      if (!(typeof(layer.interpolation) === 'undefined')) {
        s.interpolation = layer.interpolation;
      }     
     /* if (!(typeof(layer.eventHandler) === 'undefined')) {
        layer.eventHandler = (layer.eventHandler.length === "undefined") ? layer.eventHandler : [layer.eventHandler];
        layer.eventHandler.forEach(function(evt){
          s.addEventHandler(evt.event, eval(evt.handler))
        })
      }*/
        
      myChart.series.push(s);
      
      /*placeholder fix domain of primary scale for new series data
      //not working right now but something like this
      //for now just use overrideMin and overrideMax from rCharts
      for( var i = 0; i<2; i++) {
        if (!myChart.axes[i].overrideMin) {
          myChart.series[0]._axisBounds(i==0?"x":"y").min = myChart.series[0]._axisBounds(i==0?"x":"y").min < s._axisBounds(i==0?"x":"y").min ? myChart.series[0]._axisBounds(i==0?"x":"y").min : s._axisBounds(i==0?"x":"y").min;
        }
        if (!myChart.axes[i].overrideMax) {  
          myChart.series[0]._axisBounds(i==0?"x":"y")._max = myChart.series[0]._axisBounds(i==0?"x":"y").max > s._axisBounds(i==0?"x":"y").max ? myChart.series[0]._axisBounds(i==0?"x":"y").max : s._axisBounds(i==0?"x":"y").max;
        }
        myChart.axes[i]._update();
      }
      */
      
      return myChart;
    };
  
      
    //function to build axes
    function buildAxis(position, layer, myChart){
      var axis;
      var axisopts = opts[position+"Axis"];
      
      if(axisopts.measure) {
        axis = myChart[axisopts.type](position,layer[position],axisopts.measure);
      } else {
        axis = myChart[axisopts.type](position, layer[position]);
      };
      if(!(axisopts.type === "addPctAxis")) axis.showPercent = axisopts.showPercent;
      if (axisopts.orderRule) axis.addOrderRule(axisopts.orderRule);
      if (axisopts.grouporderRule) axis.addGroupOrderRule(axisopts.grouporderRule);  
      if (axisopts.overrideMin) axis.overrideMin = axisopts.overrideMin;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.inputFormat) axis.dateParseFormat = axisopts.inputFormat;
      if (axisopts.outputFormat) axis.tickFormat = axisopts.outputFormat;    
      return axis;
    };
        
        
  
    //if facet not provided for x or y make Dummy variable
    //handle NULL facet
    if (typeof opts.facet == "undefined") opts.facet = {}
    opts.facet.x = opts.facet.x ? opts.facet.x : "Dummy"
    opts.facet.y = opts.facet.y ? opts.facet.y : "Dummy"    
    if(opts.facet.x === "Dummy" || opts.facet.y === "Dummy") {
      data.forEach(function(d){
        d.Dummy = 1;
      })
    }
  
    var rows = d3.set(data.map(function(d){return d[opts.facet.y]})).values();
    var nrow = opts.facet.nrow ? opts.facet.nrow : rows.length;
    var cols = d3.set(data.map(function(d){return d[opts.facet.x]})).values()
    var ncol = opts.facet.ncol ? opts.facet.ncol : cols.length;
    
    var tuples = d3.merge(rows.map(function(row,irow){return cols.map(function(col,icol){return {key:row + "~" + col, values: {"row":irow, "col":icol} }})}))
      
    var grid = d3.layout.grid()
      .rows( nrow )
      .cols( ncol )
      .size([ opts.width, opts.height-100])
      .bands();
    
    var svgGrid = d3.select("#" + opts.id).append("svg")
      .attr("width", opts.width)
      .attr("height", opts.height);
     // .attr("transform", "translate(50,0)");
  
    grid(tuples);
  
  /* var cells = d3.select("#" + opts.id).selectAll("svg")
      .data(grid(tuples))
      .enter()
        .append("svg")
          .attr("class", "cell")
          .attr("id", function(d) {
            return d.key;
          })
          .attr("transform", function(d, i) {
             return "translate(" + d.x + "," + d.y + ")"
           })
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1]);
  
    var color = d3.scale.linear()
      .domain([0, 3, 6])
      .range(["red", "lightgray", "green"]);
      
  /*  cells.selectAll("rect")
      .data(function(d){
        return [d];
      })
        .enter().append("rect")
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1])
          .style("fill", function(d) {return color(d.values.row)});         
  */
      tuples.forEach(function(cell,cellnum) {
          //cell = d3.select(cell);
      
          // Filter the data set for the quarter and the price tier
          // of the current shape
          var filteredData = dimple.filterData(data, opts.facet.x, cell.key.split('~')[1]);
          filteredData = dimple.filterData(filteredData, opts.facet.y, cell.key.split('~')[0]);    
          
          // Draw a new chart which will go in the current shape
          var subChart = new dimple.chart(svgGrid, filteredData);
  
          if (tuples.length > 1){
            // Position the chart inside the shape
            subChart.height = grid.nodeSize()[1]
            subChart.width = grid.nodeSize()[0]      
            
            if (opts.margins) {
              subChart.setBounds(
                parseFloat(cell.x + opts.margins.left),
                parseFloat(cell.y + opts.margins.top),
                subChart.width - opts.margins.right- opts.margins.left,
                subChart.height - opts.margins.top - opts.margins.bottom
              )
            } else {
              subChart.setBounds(
                parseFloat(cell.x + 50), 
                parseFloat(cell.y + 10),
                parseFloat(grid.nodeSize()[0] - 50),
                parseFloat(grid.nodeSize()[1]) - 10
              );
            }  
          } else { //only one chart
            if (opts.bounds) {
              subChart.setBounds(opts.bounds.x, opts.bounds.y, opts.bounds.width, opts.bounds.height);//myChart.setBounds(80, 30, 480, 330);
            }
          }
          
            //dimple allows use of custom CSS with noFormats
            if(opts.noFormats) { subChart.noFormats = opts.noFormats; };
            
            //need to fix later for better colorAxis support
            if(d3.keys(opts.colorAxis).length > 0) {
              c = subChart[opts.colorAxis.type](opts.colorAxis.colorSeries,opts.colorAxis.palette) ;
              if(opts.colorAxis.outputFormat){
                c.tickFormat = opts.colorAxis.outputFormat;
              }
            }
          
            //add the colors from the array into the chart's defaultColors
            if (typeof defaultColorsArray != "undefined"){
              subChart.defaultColors = defaultColorsArray.map(function(d) {
                return new dimple.color(d);
              });          
            }
            subChart._assignedColors = assignedColors;
            
            subChart = buildSeries(opts, false, subChart);
            if (opts.layers.length > 0) {
              opts.layers.forEach(function(layer){
                subChart = buildSeries(layer, true, subChart);
              })
            }
          
            //unsure if this is best but if legend is provided (not empty) then evaluate
            if(d3.keys(opts.legend).length > 0) {
              var l =subChart.addLegend();
              d3.keys(opts.legend).forEach(function(d){
                l[d] = opts.legend[d];
              });
            }
            //quick way to get this going but need to make this cleaner
            if(opts.storyboard) {
              subChart.setStoryboard(opts.storyboard);
            };
            
            //catch all for other options
            //these can be provided by dMyChart$chart( ... )
              
            
            //add facet row and column in case we need later
            subChart.facetposition = cell.values;
            
            subCharts.push(subChart);
          })
  
      subCharts.forEach(function(subChart) {
        subChart.draw();
      })
    
    //get rid of all y for those not in column 1
    //can easily customize this to only remove bits and pieces
    if(opts.facet.removeAxes) {
      ["x","y","z"].forEach(function(position){
        //work on axis scaling
        //assume if remove then same scales for all charts
        axisdomain = [];      
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axisdomain.push(axis._scale.domain())
            }
          })
        });
        axisdomain = d3.extent([].concat.apply([], axisdomain));
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axis.overrideMin = axisdomain[0];
              axis.overrideMax = axisdomain[1];
            }
          })
          subChart.draw(null,true)
        });
      })
      
      //evaluate which do not fall in column 1 or row 1 to remove
      var xpos = d3.extent(subCharts,function(d){return d.x});
      var ypos = d3.extent(subCharts,function(d){return d.y});    
      subCharts.filter(function(d){
        return d.x!=xpos[0];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }
        d.axes.forEach(function(axis){
          if (axis.position === "y"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
      //now x for those not in row 1
      subCharts.filter(function(d){
        return d.y!=ypos[1];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }        
        d.axes.forEach(function(axis){
          if (axis.position === "x"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
    }
  return subCharts;
  }
})();
</script>
<script></script>


```r
iso %:>% dPlot(
  y = "Freq",
  x = c("iso","date"),
  groups = "date",
  data = .,
  type = "bar",
  height = 400,
  width =600
  ,xAxis = list( orderRule = sort( .$iso ) )
  ,defaultColors = tol4qualitative  
) %:>% .$show("inline")
```


<div id = 'chart2bb02ee33387' class = 'rChart dimple'></div>
<script>
var chart2bb02ee33387 = (function() {
  var opts = {
 "dom": "chart2bb02ee33387",
"width":    600,
"height":    400,
"xAxis": {
 "type": "addCategoryAxis",
"showPercent": false,
"orderRule": [ "0", "0", "0", "40", "40", "40", "50", "50", "50", "64", "64", "64", "80", "80", "80", "100", "100", "100", "125", "125", "125", "160", "160", "160", "200", "200", "200", "250", "250", "250", "320", "320", "320", "400", "400", "400", "500", "500", "500", "560", "560", "560", "640", "640", "640", "800", "800", "800", "1000", "1000", "1000", "1250", "1250", "1250", "1600", "1600", "1600", "2500", "2500", "2500", "2800", "2800", "2800", "3200", "3200", "3200" ] 
},
"yAxis": {
 "type": "addMeasureAxis",
"showPercent": false 
},
"zAxis": [],
"colorAxis": [],
"defaultColors": [ "#4477AA", "#117733", "#DDCC77", "#CC6677" ],
"layers": [],
"legend": [],
"x": [ "iso", "date" ],
"y": "Freq",
"groups": "date",
"type": "bar",
"id": "chart2bb02ee33387" 
},
    data = [{"date":"2014-07-27","iso":"0","Freq":1},{"date":"2014-07-28","iso":"0","Freq":1},{"date":"2014-07-29","iso":"0","Freq":1},{"date":"2014-07-27","iso":"40","Freq":0},{"date":"2014-07-28","iso":"40","Freq":0},{"date":"2014-07-29","iso":"40","Freq":1},{"date":"2014-07-27","iso":"50","Freq":2},{"date":"2014-07-28","iso":"50","Freq":1},{"date":"2014-07-29","iso":"50","Freq":1},{"date":"2014-07-27","iso":"64","Freq":3},{"date":"2014-07-28","iso":"64","Freq":0},{"date":"2014-07-29","iso":"64","Freq":0},{"date":"2014-07-27","iso":"80","Freq":2},{"date":"2014-07-28","iso":"80","Freq":4},{"date":"2014-07-29","iso":"80","Freq":1},{"date":"2014-07-27","iso":"100","Freq":18},{"date":"2014-07-28","iso":"100","Freq":21},{"date":"2014-07-29","iso":"100","Freq":21},{"date":"2014-07-27","iso":"125","Freq":4},{"date":"2014-07-28","iso":"125","Freq":0},{"date":"2014-07-29","iso":"125","Freq":2},{"date":"2014-07-27","iso":"160","Freq":3},{"date":"2014-07-28","iso":"160","Freq":2},{"date":"2014-07-29","iso":"160","Freq":6},{"date":"2014-07-27","iso":"200","Freq":17},{"date":"2014-07-28","iso":"200","Freq":16},{"date":"2014-07-29","iso":"200","Freq":15},{"date":"2014-07-27","iso":"250","Freq":5},{"date":"2014-07-28","iso":"250","Freq":4},{"date":"2014-07-29","iso":"250","Freq":1},{"date":"2014-07-27","iso":"320","Freq":1},{"date":"2014-07-28","iso":"320","Freq":4},{"date":"2014-07-29","iso":"320","Freq":2},{"date":"2014-07-27","iso":"400","Freq":8},{"date":"2014-07-28","iso":"400","Freq":2},{"date":"2014-07-29","iso":"400","Freq":8},{"date":"2014-07-27","iso":"500","Freq":0},{"date":"2014-07-28","iso":"500","Freq":2},{"date":"2014-07-29","iso":"500","Freq":1},{"date":"2014-07-27","iso":"560","Freq":1},{"date":"2014-07-28","iso":"560","Freq":0},{"date":"2014-07-29","iso":"560","Freq":1},{"date":"2014-07-27","iso":"640","Freq":0},{"date":"2014-07-28","iso":"640","Freq":1},{"date":"2014-07-29","iso":"640","Freq":0},{"date":"2014-07-27","iso":"800","Freq":1},{"date":"2014-07-28","iso":"800","Freq":1},{"date":"2014-07-29","iso":"800","Freq":3},{"date":"2014-07-27","iso":"1000","Freq":2},{"date":"2014-07-28","iso":"1000","Freq":1},{"date":"2014-07-29","iso":"1000","Freq":1},{"date":"2014-07-27","iso":"1250","Freq":1},{"date":"2014-07-28","iso":"1250","Freq":1},{"date":"2014-07-29","iso":"1250","Freq":1},{"date":"2014-07-27","iso":"1600","Freq":1},{"date":"2014-07-28","iso":"1600","Freq":1},{"date":"2014-07-29","iso":"1600","Freq":1},{"date":"2014-07-27","iso":"2500","Freq":0},{"date":"2014-07-28","iso":"2500","Freq":0},{"date":"2014-07-29","iso":"2500","Freq":1},{"date":"2014-07-27","iso":"2800","Freq":0},{"date":"2014-07-28","iso":"2800","Freq":1},{"date":"2014-07-29","iso":"2800","Freq":0},{"date":"2014-07-27","iso":"3200","Freq":1},{"date":"2014-07-28","iso":"3200","Freq":1},{"date":"2014-07-29","iso":"3200","Freq":0}];
  
  return drawChart(opts,data);
  
  function drawChart(opts, data){ 
    var subCharts = [];
    
    var c = null;
    var assignedColors = {};
    
      //move this to top or make function since duplicated
    //allow manipulation of default colors to use with dimple
    if(opts.defaultColors.length) {
      defaultColorsArray = [];
      if (typeof(opts.defaultColors) == "function") {
        //assume this is a d3 scale
        //if there is a domain for the color scale given
        //then we will need to assign colors with dimples assignColor
        if( opts.defaultColors.domain().length > 0 ){
          defaultColorsArray = opts.defaultColors.range();
          opts.defaultColors.domain().forEach( function( d, i ) {
            assignedColors[d] = new dimple.color(opts.defaultColors.range()[i])
          })
        } else {
          for (var n=0;n<opts.defaultColors.range().length;n++) {
            defaultColorsArray.push(opts.defaultColors(n));
          };
        }
      } else {
        defaultColorsArray = opts.defaultColors;
      }
  
      
      //if colors not assigned with no keys and opts.groups
      if (!(Object.keys(assignedColors).length) & Boolean(opts.groups)) {
        //let's just assign colors in order with each unique
        //this is important if facetting where need colors assigned
        //if not in all pairs
        opts.groups = (typeof opts.groups == "string") ? [opts.groups] : opts.groups;
        d3.set(
          data.map(function(d){
            //dimple colors by last item in groups
            return d[opts.groups[opts.groups.length-1]]
          })
        ).values().forEach(function(u,i){
          //u will be our uniqe and will pick color from defaultColorsArray
          //console.log([u,defaultColorsArray[i]].concat());
          assignedColors[u] = new dimple.color(defaultColorsArray[i % defaultColorsArray.length])
        })
      }
    }
  
    
    //do series
    //set up a function since same for each
    //as of now we have x,y,groups,data,type in opts for primary layer
    //and other layers reside in opts.layers
    function buildSeries(layer, hidden, myChart){
      //inherit from primary layer if not intentionally changed or xAxis, yAxis, zAxis null
      if (!layer.xAxis) layer.xAxis = opts.xAxis;    
      if (!layer.yAxis) layer.yAxis = opts.yAxis;
      if (!layer.zAxis) layer.zAxis = opts.zAxis;
      
      var x = buildAxis("x", layer, myChart);
      x.hidden = hidden;
      
      var y = buildAxis("y", layer, myChart);
      y.hidden = hidden;
      
      //z for bubbles
      var z = null;
      if (!(typeof(layer.zAxis) === 'undefined') && layer.zAxis.type){
        z = buildAxis("z", layer, myChart);
      };
      
      //here think I need to evaluate group and if missing do null
      //as the group argument
      //if provided need to use groups from layer
      var s = new dimple.series(myChart, null, x, y, z, c, dimple.plot[layer.type], dimple.aggregateMethod.avg, dimple.plot[layer.type].stacked);
      
      //as of v1.1.4 dimple can use different dataset for each series
      if(layer.data){
        //convert to an array of objects
        var tempdata;
        //avoid lodash for now
        datakeys = d3.keys(layer.data)
        tempdata = layer.data[datakeys[1]].map(function(d,i){
          var tempobj = {}
          datakeys.forEach(function(key){
            tempobj[key] = layer.data[key][i]
          })
          return tempobj
        })
        s.data = tempdata;
      }
      
      if(layer.hasOwnProperty("groups")) {
        s.categoryFields = (typeof layer.groups === "object") ? layer.groups : [layer.groups];
        //series offers an aggregate method that we will also need to check if available
        //options available are avg, count, max, min, sum
      }
      if (!(typeof(layer.aggregate) === 'undefined')) {
        s.aggregate = eval(layer.aggregate);
      }
      if (!(typeof(layer.lineWeight) === 'undefined')) {
        s.lineWeight = layer.lineWeight;
      }
      if (!(typeof(layer.barGap) === 'undefined')) {
        s.barGap = layer.barGap;
      }    
      if (!(typeof(layer.interpolation) === 'undefined')) {
        s.interpolation = layer.interpolation;
      }     
     /* if (!(typeof(layer.eventHandler) === 'undefined')) {
        layer.eventHandler = (layer.eventHandler.length === "undefined") ? layer.eventHandler : [layer.eventHandler];
        layer.eventHandler.forEach(function(evt){
          s.addEventHandler(evt.event, eval(evt.handler))
        })
      }*/
        
      myChart.series.push(s);
      
      /*placeholder fix domain of primary scale for new series data
      //not working right now but something like this
      //for now just use overrideMin and overrideMax from rCharts
      for( var i = 0; i<2; i++) {
        if (!myChart.axes[i].overrideMin) {
          myChart.series[0]._axisBounds(i==0?"x":"y").min = myChart.series[0]._axisBounds(i==0?"x":"y").min < s._axisBounds(i==0?"x":"y").min ? myChart.series[0]._axisBounds(i==0?"x":"y").min : s._axisBounds(i==0?"x":"y").min;
        }
        if (!myChart.axes[i].overrideMax) {  
          myChart.series[0]._axisBounds(i==0?"x":"y")._max = myChart.series[0]._axisBounds(i==0?"x":"y").max > s._axisBounds(i==0?"x":"y").max ? myChart.series[0]._axisBounds(i==0?"x":"y").max : s._axisBounds(i==0?"x":"y").max;
        }
        myChart.axes[i]._update();
      }
      */
      
      return myChart;
    };
  
      
    //function to build axes
    function buildAxis(position, layer, myChart){
      var axis;
      var axisopts = opts[position+"Axis"];
      
      if(axisopts.measure) {
        axis = myChart[axisopts.type](position,layer[position],axisopts.measure);
      } else {
        axis = myChart[axisopts.type](position, layer[position]);
      };
      if(!(axisopts.type === "addPctAxis")) axis.showPercent = axisopts.showPercent;
      if (axisopts.orderRule) axis.addOrderRule(axisopts.orderRule);
      if (axisopts.grouporderRule) axis.addGroupOrderRule(axisopts.grouporderRule);  
      if (axisopts.overrideMin) axis.overrideMin = axisopts.overrideMin;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.inputFormat) axis.dateParseFormat = axisopts.inputFormat;
      if (axisopts.outputFormat) axis.tickFormat = axisopts.outputFormat;    
      return axis;
    };
        
        
  
    //if facet not provided for x or y make Dummy variable
    //handle NULL facet
    if (typeof opts.facet == "undefined") opts.facet = {}
    opts.facet.x = opts.facet.x ? opts.facet.x : "Dummy"
    opts.facet.y = opts.facet.y ? opts.facet.y : "Dummy"    
    if(opts.facet.x === "Dummy" || opts.facet.y === "Dummy") {
      data.forEach(function(d){
        d.Dummy = 1;
      })
    }
  
    var rows = d3.set(data.map(function(d){return d[opts.facet.y]})).values();
    var nrow = opts.facet.nrow ? opts.facet.nrow : rows.length;
    var cols = d3.set(data.map(function(d){return d[opts.facet.x]})).values()
    var ncol = opts.facet.ncol ? opts.facet.ncol : cols.length;
    
    var tuples = d3.merge(rows.map(function(row,irow){return cols.map(function(col,icol){return {key:row + "~" + col, values: {"row":irow, "col":icol} }})}))
      
    var grid = d3.layout.grid()
      .rows( nrow )
      .cols( ncol )
      .size([ opts.width, opts.height-100])
      .bands();
    
    var svgGrid = d3.select("#" + opts.id).append("svg")
      .attr("width", opts.width)
      .attr("height", opts.height);
     // .attr("transform", "translate(50,0)");
  
    grid(tuples);
  
  /* var cells = d3.select("#" + opts.id).selectAll("svg")
      .data(grid(tuples))
      .enter()
        .append("svg")
          .attr("class", "cell")
          .attr("id", function(d) {
            return d.key;
          })
          .attr("transform", function(d, i) {
             return "translate(" + d.x + "," + d.y + ")"
           })
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1]);
  
    var color = d3.scale.linear()
      .domain([0, 3, 6])
      .range(["red", "lightgray", "green"]);
      
  /*  cells.selectAll("rect")
      .data(function(d){
        return [d];
      })
        .enter().append("rect")
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1])
          .style("fill", function(d) {return color(d.values.row)});         
  */
      tuples.forEach(function(cell,cellnum) {
          //cell = d3.select(cell);
      
          // Filter the data set for the quarter and the price tier
          // of the current shape
          var filteredData = dimple.filterData(data, opts.facet.x, cell.key.split('~')[1]);
          filteredData = dimple.filterData(filteredData, opts.facet.y, cell.key.split('~')[0]);    
          
          // Draw a new chart which will go in the current shape
          var subChart = new dimple.chart(svgGrid, filteredData);
  
          if (tuples.length > 1){
            // Position the chart inside the shape
            subChart.height = grid.nodeSize()[1]
            subChart.width = grid.nodeSize()[0]      
            
            if (opts.margins) {
              subChart.setBounds(
                parseFloat(cell.x + opts.margins.left),
                parseFloat(cell.y + opts.margins.top),
                subChart.width - opts.margins.right- opts.margins.left,
                subChart.height - opts.margins.top - opts.margins.bottom
              )
            } else {
              subChart.setBounds(
                parseFloat(cell.x + 50), 
                parseFloat(cell.y + 10),
                parseFloat(grid.nodeSize()[0] - 50),
                parseFloat(grid.nodeSize()[1]) - 10
              );
            }  
          } else { //only one chart
            if (opts.bounds) {
              subChart.setBounds(opts.bounds.x, opts.bounds.y, opts.bounds.width, opts.bounds.height);//myChart.setBounds(80, 30, 480, 330);
            }
          }
          
            //dimple allows use of custom CSS with noFormats
            if(opts.noFormats) { subChart.noFormats = opts.noFormats; };
            
            //need to fix later for better colorAxis support
            if(d3.keys(opts.colorAxis).length > 0) {
              c = subChart[opts.colorAxis.type](opts.colorAxis.colorSeries,opts.colorAxis.palette) ;
              if(opts.colorAxis.outputFormat){
                c.tickFormat = opts.colorAxis.outputFormat;
              }
            }
          
            //add the colors from the array into the chart's defaultColors
            if (typeof defaultColorsArray != "undefined"){
              subChart.defaultColors = defaultColorsArray.map(function(d) {
                return new dimple.color(d);
              });          
            }
            subChart._assignedColors = assignedColors;
            
            subChart = buildSeries(opts, false, subChart);
            if (opts.layers.length > 0) {
              opts.layers.forEach(function(layer){
                subChart = buildSeries(layer, true, subChart);
              })
            }
          
            //unsure if this is best but if legend is provided (not empty) then evaluate
            if(d3.keys(opts.legend).length > 0) {
              var l =subChart.addLegend();
              d3.keys(opts.legend).forEach(function(d){
                l[d] = opts.legend[d];
              });
            }
            //quick way to get this going but need to make this cleaner
            if(opts.storyboard) {
              subChart.setStoryboard(opts.storyboard);
            };
            
            //catch all for other options
            //these can be provided by dMyChart$chart( ... )
              
            
            //add facet row and column in case we need later
            subChart.facetposition = cell.values;
            
            subCharts.push(subChart);
          })
  
      subCharts.forEach(function(subChart) {
        subChart.draw();
      })
    
    //get rid of all y for those not in column 1
    //can easily customize this to only remove bits and pieces
    if(opts.facet.removeAxes) {
      ["x","y","z"].forEach(function(position){
        //work on axis scaling
        //assume if remove then same scales for all charts
        axisdomain = [];      
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axisdomain.push(axis._scale.domain())
            }
          })
        });
        axisdomain = d3.extent([].concat.apply([], axisdomain));
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axis.overrideMin = axisdomain[0];
              axis.overrideMax = axisdomain[1];
            }
          })
          subChart.draw(null,true)
        });
      })
      
      //evaluate which do not fall in column 1 or row 1 to remove
      var xpos = d3.extent(subCharts,function(d){return d.x});
      var ypos = d3.extent(subCharts,function(d){return d.y});    
      subCharts.filter(function(d){
        return d.x!=xpos[0];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }
        d.axes.forEach(function(axis){
          if (axis.position === "y"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
      //now x for those not in row 1
      subCharts.filter(function(d){
        return d.y!=ypos[1];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }        
        d.axes.forEach(function(axis){
          if (axis.position === "x"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
    }
  return subCharts;
  }
})();
</script>
<script></script>


```r
iso %:>% dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = .,
  type = "bar",
  height = 400,
  width =600
  ,xAxis = list( grouporderRule = sort( .$iso ) )
  ,defaultColors = tol4qualitative 
)  %:>% .$show("inline")
```


<div id = 'chart2bb06f225d90' class = 'rChart dimple'></div>
<script>
var chart2bb06f225d90 = (function() {
  var opts = {
 "dom": "chart2bb06f225d90",
"width":    600,
"height":    400,
"xAxis": {
 "type": "addCategoryAxis",
"showPercent": false,
"grouporderRule": [ "0", "0", "0", "40", "40", "40", "50", "50", "50", "64", "64", "64", "80", "80", "80", "100", "100", "100", "125", "125", "125", "160", "160", "160", "200", "200", "200", "250", "250", "250", "320", "320", "320", "400", "400", "400", "500", "500", "500", "560", "560", "560", "640", "640", "640", "800", "800", "800", "1000", "1000", "1000", "1250", "1250", "1250", "1600", "1600", "1600", "2500", "2500", "2500", "2800", "2800", "2800", "3200", "3200", "3200" ] 
},
"yAxis": {
 "type": "addMeasureAxis",
"showPercent": false 
},
"zAxis": [],
"colorAxis": [],
"defaultColors": [ "#4477AA", "#117733", "#DDCC77", "#CC6677" ],
"layers": [],
"legend": [],
"x": [ "date", "iso" ],
"y": "Freq",
"groups": "date",
"type": "bar",
"id": "chart2bb06f225d90" 
},
    data = [{"date":"2014-07-27","iso":"0","Freq":1},{"date":"2014-07-28","iso":"0","Freq":1},{"date":"2014-07-29","iso":"0","Freq":1},{"date":"2014-07-27","iso":"40","Freq":0},{"date":"2014-07-28","iso":"40","Freq":0},{"date":"2014-07-29","iso":"40","Freq":1},{"date":"2014-07-27","iso":"50","Freq":2},{"date":"2014-07-28","iso":"50","Freq":1},{"date":"2014-07-29","iso":"50","Freq":1},{"date":"2014-07-27","iso":"64","Freq":3},{"date":"2014-07-28","iso":"64","Freq":0},{"date":"2014-07-29","iso":"64","Freq":0},{"date":"2014-07-27","iso":"80","Freq":2},{"date":"2014-07-28","iso":"80","Freq":4},{"date":"2014-07-29","iso":"80","Freq":1},{"date":"2014-07-27","iso":"100","Freq":18},{"date":"2014-07-28","iso":"100","Freq":21},{"date":"2014-07-29","iso":"100","Freq":21},{"date":"2014-07-27","iso":"125","Freq":4},{"date":"2014-07-28","iso":"125","Freq":0},{"date":"2014-07-29","iso":"125","Freq":2},{"date":"2014-07-27","iso":"160","Freq":3},{"date":"2014-07-28","iso":"160","Freq":2},{"date":"2014-07-29","iso":"160","Freq":6},{"date":"2014-07-27","iso":"200","Freq":17},{"date":"2014-07-28","iso":"200","Freq":16},{"date":"2014-07-29","iso":"200","Freq":15},{"date":"2014-07-27","iso":"250","Freq":5},{"date":"2014-07-28","iso":"250","Freq":4},{"date":"2014-07-29","iso":"250","Freq":1},{"date":"2014-07-27","iso":"320","Freq":1},{"date":"2014-07-28","iso":"320","Freq":4},{"date":"2014-07-29","iso":"320","Freq":2},{"date":"2014-07-27","iso":"400","Freq":8},{"date":"2014-07-28","iso":"400","Freq":2},{"date":"2014-07-29","iso":"400","Freq":8},{"date":"2014-07-27","iso":"500","Freq":0},{"date":"2014-07-28","iso":"500","Freq":2},{"date":"2014-07-29","iso":"500","Freq":1},{"date":"2014-07-27","iso":"560","Freq":1},{"date":"2014-07-28","iso":"560","Freq":0},{"date":"2014-07-29","iso":"560","Freq":1},{"date":"2014-07-27","iso":"640","Freq":0},{"date":"2014-07-28","iso":"640","Freq":1},{"date":"2014-07-29","iso":"640","Freq":0},{"date":"2014-07-27","iso":"800","Freq":1},{"date":"2014-07-28","iso":"800","Freq":1},{"date":"2014-07-29","iso":"800","Freq":3},{"date":"2014-07-27","iso":"1000","Freq":2},{"date":"2014-07-28","iso":"1000","Freq":1},{"date":"2014-07-29","iso":"1000","Freq":1},{"date":"2014-07-27","iso":"1250","Freq":1},{"date":"2014-07-28","iso":"1250","Freq":1},{"date":"2014-07-29","iso":"1250","Freq":1},{"date":"2014-07-27","iso":"1600","Freq":1},{"date":"2014-07-28","iso":"1600","Freq":1},{"date":"2014-07-29","iso":"1600","Freq":1},{"date":"2014-07-27","iso":"2500","Freq":0},{"date":"2014-07-28","iso":"2500","Freq":0},{"date":"2014-07-29","iso":"2500","Freq":1},{"date":"2014-07-27","iso":"2800","Freq":0},{"date":"2014-07-28","iso":"2800","Freq":1},{"date":"2014-07-29","iso":"2800","Freq":0},{"date":"2014-07-27","iso":"3200","Freq":1},{"date":"2014-07-28","iso":"3200","Freq":1},{"date":"2014-07-29","iso":"3200","Freq":0}];
  
  return drawChart(opts,data);
  
  function drawChart(opts, data){ 
    var subCharts = [];
    
    var c = null;
    var assignedColors = {};
    
      //move this to top or make function since duplicated
    //allow manipulation of default colors to use with dimple
    if(opts.defaultColors.length) {
      defaultColorsArray = [];
      if (typeof(opts.defaultColors) == "function") {
        //assume this is a d3 scale
        //if there is a domain for the color scale given
        //then we will need to assign colors with dimples assignColor
        if( opts.defaultColors.domain().length > 0 ){
          defaultColorsArray = opts.defaultColors.range();
          opts.defaultColors.domain().forEach( function( d, i ) {
            assignedColors[d] = new dimple.color(opts.defaultColors.range()[i])
          })
        } else {
          for (var n=0;n<opts.defaultColors.range().length;n++) {
            defaultColorsArray.push(opts.defaultColors(n));
          };
        }
      } else {
        defaultColorsArray = opts.defaultColors;
      }
  
      
      //if colors not assigned with no keys and opts.groups
      if (!(Object.keys(assignedColors).length) & Boolean(opts.groups)) {
        //let's just assign colors in order with each unique
        //this is important if facetting where need colors assigned
        //if not in all pairs
        opts.groups = (typeof opts.groups == "string") ? [opts.groups] : opts.groups;
        d3.set(
          data.map(function(d){
            //dimple colors by last item in groups
            return d[opts.groups[opts.groups.length-1]]
          })
        ).values().forEach(function(u,i){
          //u will be our uniqe and will pick color from defaultColorsArray
          //console.log([u,defaultColorsArray[i]].concat());
          assignedColors[u] = new dimple.color(defaultColorsArray[i % defaultColorsArray.length])
        })
      }
    }
  
    
    //do series
    //set up a function since same for each
    //as of now we have x,y,groups,data,type in opts for primary layer
    //and other layers reside in opts.layers
    function buildSeries(layer, hidden, myChart){
      //inherit from primary layer if not intentionally changed or xAxis, yAxis, zAxis null
      if (!layer.xAxis) layer.xAxis = opts.xAxis;    
      if (!layer.yAxis) layer.yAxis = opts.yAxis;
      if (!layer.zAxis) layer.zAxis = opts.zAxis;
      
      var x = buildAxis("x", layer, myChart);
      x.hidden = hidden;
      
      var y = buildAxis("y", layer, myChart);
      y.hidden = hidden;
      
      //z for bubbles
      var z = null;
      if (!(typeof(layer.zAxis) === 'undefined') && layer.zAxis.type){
        z = buildAxis("z", layer, myChart);
      };
      
      //here think I need to evaluate group and if missing do null
      //as the group argument
      //if provided need to use groups from layer
      var s = new dimple.series(myChart, null, x, y, z, c, dimple.plot[layer.type], dimple.aggregateMethod.avg, dimple.plot[layer.type].stacked);
      
      //as of v1.1.4 dimple can use different dataset for each series
      if(layer.data){
        //convert to an array of objects
        var tempdata;
        //avoid lodash for now
        datakeys = d3.keys(layer.data)
        tempdata = layer.data[datakeys[1]].map(function(d,i){
          var tempobj = {}
          datakeys.forEach(function(key){
            tempobj[key] = layer.data[key][i]
          })
          return tempobj
        })
        s.data = tempdata;
      }
      
      if(layer.hasOwnProperty("groups")) {
        s.categoryFields = (typeof layer.groups === "object") ? layer.groups : [layer.groups];
        //series offers an aggregate method that we will also need to check if available
        //options available are avg, count, max, min, sum
      }
      if (!(typeof(layer.aggregate) === 'undefined')) {
        s.aggregate = eval(layer.aggregate);
      }
      if (!(typeof(layer.lineWeight) === 'undefined')) {
        s.lineWeight = layer.lineWeight;
      }
      if (!(typeof(layer.barGap) === 'undefined')) {
        s.barGap = layer.barGap;
      }    
      if (!(typeof(layer.interpolation) === 'undefined')) {
        s.interpolation = layer.interpolation;
      }     
     /* if (!(typeof(layer.eventHandler) === 'undefined')) {
        layer.eventHandler = (layer.eventHandler.length === "undefined") ? layer.eventHandler : [layer.eventHandler];
        layer.eventHandler.forEach(function(evt){
          s.addEventHandler(evt.event, eval(evt.handler))
        })
      }*/
        
      myChart.series.push(s);
      
      /*placeholder fix domain of primary scale for new series data
      //not working right now but something like this
      //for now just use overrideMin and overrideMax from rCharts
      for( var i = 0; i<2; i++) {
        if (!myChart.axes[i].overrideMin) {
          myChart.series[0]._axisBounds(i==0?"x":"y").min = myChart.series[0]._axisBounds(i==0?"x":"y").min < s._axisBounds(i==0?"x":"y").min ? myChart.series[0]._axisBounds(i==0?"x":"y").min : s._axisBounds(i==0?"x":"y").min;
        }
        if (!myChart.axes[i].overrideMax) {  
          myChart.series[0]._axisBounds(i==0?"x":"y")._max = myChart.series[0]._axisBounds(i==0?"x":"y").max > s._axisBounds(i==0?"x":"y").max ? myChart.series[0]._axisBounds(i==0?"x":"y").max : s._axisBounds(i==0?"x":"y").max;
        }
        myChart.axes[i]._update();
      }
      */
      
      return myChart;
    };
  
      
    //function to build axes
    function buildAxis(position, layer, myChart){
      var axis;
      var axisopts = opts[position+"Axis"];
      
      if(axisopts.measure) {
        axis = myChart[axisopts.type](position,layer[position],axisopts.measure);
      } else {
        axis = myChart[axisopts.type](position, layer[position]);
      };
      if(!(axisopts.type === "addPctAxis")) axis.showPercent = axisopts.showPercent;
      if (axisopts.orderRule) axis.addOrderRule(axisopts.orderRule);
      if (axisopts.grouporderRule) axis.addGroupOrderRule(axisopts.grouporderRule);  
      if (axisopts.overrideMin) axis.overrideMin = axisopts.overrideMin;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.inputFormat) axis.dateParseFormat = axisopts.inputFormat;
      if (axisopts.outputFormat) axis.tickFormat = axisopts.outputFormat;    
      return axis;
    };
        
        
  
    //if facet not provided for x or y make Dummy variable
    //handle NULL facet
    if (typeof opts.facet == "undefined") opts.facet = {}
    opts.facet.x = opts.facet.x ? opts.facet.x : "Dummy"
    opts.facet.y = opts.facet.y ? opts.facet.y : "Dummy"    
    if(opts.facet.x === "Dummy" || opts.facet.y === "Dummy") {
      data.forEach(function(d){
        d.Dummy = 1;
      })
    }
  
    var rows = d3.set(data.map(function(d){return d[opts.facet.y]})).values();
    var nrow = opts.facet.nrow ? opts.facet.nrow : rows.length;
    var cols = d3.set(data.map(function(d){return d[opts.facet.x]})).values()
    var ncol = opts.facet.ncol ? opts.facet.ncol : cols.length;
    
    var tuples = d3.merge(rows.map(function(row,irow){return cols.map(function(col,icol){return {key:row + "~" + col, values: {"row":irow, "col":icol} }})}))
      
    var grid = d3.layout.grid()
      .rows( nrow )
      .cols( ncol )
      .size([ opts.width, opts.height-100])
      .bands();
    
    var svgGrid = d3.select("#" + opts.id).append("svg")
      .attr("width", opts.width)
      .attr("height", opts.height);
     // .attr("transform", "translate(50,0)");
  
    grid(tuples);
  
  /* var cells = d3.select("#" + opts.id).selectAll("svg")
      .data(grid(tuples))
      .enter()
        .append("svg")
          .attr("class", "cell")
          .attr("id", function(d) {
            return d.key;
          })
          .attr("transform", function(d, i) {
             return "translate(" + d.x + "," + d.y + ")"
           })
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1]);
  
    var color = d3.scale.linear()
      .domain([0, 3, 6])
      .range(["red", "lightgray", "green"]);
      
  /*  cells.selectAll("rect")
      .data(function(d){
        return [d];
      })
        .enter().append("rect")
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1])
          .style("fill", function(d) {return color(d.values.row)});         
  */
      tuples.forEach(function(cell,cellnum) {
          //cell = d3.select(cell);
      
          // Filter the data set for the quarter and the price tier
          // of the current shape
          var filteredData = dimple.filterData(data, opts.facet.x, cell.key.split('~')[1]);
          filteredData = dimple.filterData(filteredData, opts.facet.y, cell.key.split('~')[0]);    
          
          // Draw a new chart which will go in the current shape
          var subChart = new dimple.chart(svgGrid, filteredData);
  
          if (tuples.length > 1){
            // Position the chart inside the shape
            subChart.height = grid.nodeSize()[1]
            subChart.width = grid.nodeSize()[0]      
            
            if (opts.margins) {
              subChart.setBounds(
                parseFloat(cell.x + opts.margins.left),
                parseFloat(cell.y + opts.margins.top),
                subChart.width - opts.margins.right- opts.margins.left,
                subChart.height - opts.margins.top - opts.margins.bottom
              )
            } else {
              subChart.setBounds(
                parseFloat(cell.x + 50), 
                parseFloat(cell.y + 10),
                parseFloat(grid.nodeSize()[0] - 50),
                parseFloat(grid.nodeSize()[1]) - 10
              );
            }  
          } else { //only one chart
            if (opts.bounds) {
              subChart.setBounds(opts.bounds.x, opts.bounds.y, opts.bounds.width, opts.bounds.height);//myChart.setBounds(80, 30, 480, 330);
            }
          }
          
            //dimple allows use of custom CSS with noFormats
            if(opts.noFormats) { subChart.noFormats = opts.noFormats; };
            
            //need to fix later for better colorAxis support
            if(d3.keys(opts.colorAxis).length > 0) {
              c = subChart[opts.colorAxis.type](opts.colorAxis.colorSeries,opts.colorAxis.palette) ;
              if(opts.colorAxis.outputFormat){
                c.tickFormat = opts.colorAxis.outputFormat;
              }
            }
          
            //add the colors from the array into the chart's defaultColors
            if (typeof defaultColorsArray != "undefined"){
              subChart.defaultColors = defaultColorsArray.map(function(d) {
                return new dimple.color(d);
              });          
            }
            subChart._assignedColors = assignedColors;
            
            subChart = buildSeries(opts, false, subChart);
            if (opts.layers.length > 0) {
              opts.layers.forEach(function(layer){
                subChart = buildSeries(layer, true, subChart);
              })
            }
          
            //unsure if this is best but if legend is provided (not empty) then evaluate
            if(d3.keys(opts.legend).length > 0) {
              var l =subChart.addLegend();
              d3.keys(opts.legend).forEach(function(d){
                l[d] = opts.legend[d];
              });
            }
            //quick way to get this going but need to make this cleaner
            if(opts.storyboard) {
              subChart.setStoryboard(opts.storyboard);
            };
            
            //catch all for other options
            //these can be provided by dMyChart$chart( ... )
              
            
            //add facet row and column in case we need later
            subChart.facetposition = cell.values;
            
            subCharts.push(subChart);
          })
  
      subCharts.forEach(function(subChart) {
        subChart.draw();
      })
    
    //get rid of all y for those not in column 1
    //can easily customize this to only remove bits and pieces
    if(opts.facet.removeAxes) {
      ["x","y","z"].forEach(function(position){
        //work on axis scaling
        //assume if remove then same scales for all charts
        axisdomain = [];      
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axisdomain.push(axis._scale.domain())
            }
          })
        });
        axisdomain = d3.extent([].concat.apply([], axisdomain));
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axis.overrideMin = axisdomain[0];
              axis.overrideMax = axisdomain[1];
            }
          })
          subChart.draw(null,true)
        });
      })
      
      //evaluate which do not fall in column 1 or row 1 to remove
      var xpos = d3.extent(subCharts,function(d){return d.x});
      var ypos = d3.extent(subCharts,function(d){return d.y});    
      subCharts.filter(function(d){
        return d.x!=xpos[0];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }
        d.axes.forEach(function(axis){
          if (axis.position === "y"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
      //now x for those not in row 1
      subCharts.filter(function(d){
        return d.y!=ypos[1];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }        
        d.axes.forEach(function(axis){
          if (axis.position === "x"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
    }
  return subCharts;
  }
})();
</script>
<script></script>


```r
iso %:>% dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = .,
  type = "line",
  height = 400,
  width =600
  ,xAxis = list( orderRule = sort( .$iso ) )
  ,defaultColors = tol4qualitative   
) %:>% .$show("inline")
```


<div id = 'chart2bb02ab8101f' class = 'rChart dimple'></div>
<script>
var chart2bb02ab8101f = (function() {
  var opts = {
 "dom": "chart2bb02ab8101f",
"width":    600,
"height":    400,
"xAxis": {
 "type": "addCategoryAxis",
"showPercent": false,
"orderRule": [ "0", "0", "0", "40", "40", "40", "50", "50", "50", "64", "64", "64", "80", "80", "80", "100", "100", "100", "125", "125", "125", "160", "160", "160", "200", "200", "200", "250", "250", "250", "320", "320", "320", "400", "400", "400", "500", "500", "500", "560", "560", "560", "640", "640", "640", "800", "800", "800", "1000", "1000", "1000", "1250", "1250", "1250", "1600", "1600", "1600", "2500", "2500", "2500", "2800", "2800", "2800", "3200", "3200", "3200" ] 
},
"yAxis": {
 "type": "addMeasureAxis",
"showPercent": false 
},
"zAxis": [],
"colorAxis": [],
"defaultColors": [ "#4477AA", "#117733", "#DDCC77", "#CC6677" ],
"layers": [],
"legend": [],
"x": "iso",
"y": "Freq",
"groups": "date",
"type": "line",
"id": "chart2bb02ab8101f" 
},
    data = [{"date":"2014-07-27","iso":"0","Freq":1},{"date":"2014-07-28","iso":"0","Freq":1},{"date":"2014-07-29","iso":"0","Freq":1},{"date":"2014-07-27","iso":"40","Freq":0},{"date":"2014-07-28","iso":"40","Freq":0},{"date":"2014-07-29","iso":"40","Freq":1},{"date":"2014-07-27","iso":"50","Freq":2},{"date":"2014-07-28","iso":"50","Freq":1},{"date":"2014-07-29","iso":"50","Freq":1},{"date":"2014-07-27","iso":"64","Freq":3},{"date":"2014-07-28","iso":"64","Freq":0},{"date":"2014-07-29","iso":"64","Freq":0},{"date":"2014-07-27","iso":"80","Freq":2},{"date":"2014-07-28","iso":"80","Freq":4},{"date":"2014-07-29","iso":"80","Freq":1},{"date":"2014-07-27","iso":"100","Freq":18},{"date":"2014-07-28","iso":"100","Freq":21},{"date":"2014-07-29","iso":"100","Freq":21},{"date":"2014-07-27","iso":"125","Freq":4},{"date":"2014-07-28","iso":"125","Freq":0},{"date":"2014-07-29","iso":"125","Freq":2},{"date":"2014-07-27","iso":"160","Freq":3},{"date":"2014-07-28","iso":"160","Freq":2},{"date":"2014-07-29","iso":"160","Freq":6},{"date":"2014-07-27","iso":"200","Freq":17},{"date":"2014-07-28","iso":"200","Freq":16},{"date":"2014-07-29","iso":"200","Freq":15},{"date":"2014-07-27","iso":"250","Freq":5},{"date":"2014-07-28","iso":"250","Freq":4},{"date":"2014-07-29","iso":"250","Freq":1},{"date":"2014-07-27","iso":"320","Freq":1},{"date":"2014-07-28","iso":"320","Freq":4},{"date":"2014-07-29","iso":"320","Freq":2},{"date":"2014-07-27","iso":"400","Freq":8},{"date":"2014-07-28","iso":"400","Freq":2},{"date":"2014-07-29","iso":"400","Freq":8},{"date":"2014-07-27","iso":"500","Freq":0},{"date":"2014-07-28","iso":"500","Freq":2},{"date":"2014-07-29","iso":"500","Freq":1},{"date":"2014-07-27","iso":"560","Freq":1},{"date":"2014-07-28","iso":"560","Freq":0},{"date":"2014-07-29","iso":"560","Freq":1},{"date":"2014-07-27","iso":"640","Freq":0},{"date":"2014-07-28","iso":"640","Freq":1},{"date":"2014-07-29","iso":"640","Freq":0},{"date":"2014-07-27","iso":"800","Freq":1},{"date":"2014-07-28","iso":"800","Freq":1},{"date":"2014-07-29","iso":"800","Freq":3},{"date":"2014-07-27","iso":"1000","Freq":2},{"date":"2014-07-28","iso":"1000","Freq":1},{"date":"2014-07-29","iso":"1000","Freq":1},{"date":"2014-07-27","iso":"1250","Freq":1},{"date":"2014-07-28","iso":"1250","Freq":1},{"date":"2014-07-29","iso":"1250","Freq":1},{"date":"2014-07-27","iso":"1600","Freq":1},{"date":"2014-07-28","iso":"1600","Freq":1},{"date":"2014-07-29","iso":"1600","Freq":1},{"date":"2014-07-27","iso":"2500","Freq":0},{"date":"2014-07-28","iso":"2500","Freq":0},{"date":"2014-07-29","iso":"2500","Freq":1},{"date":"2014-07-27","iso":"2800","Freq":0},{"date":"2014-07-28","iso":"2800","Freq":1},{"date":"2014-07-29","iso":"2800","Freq":0},{"date":"2014-07-27","iso":"3200","Freq":1},{"date":"2014-07-28","iso":"3200","Freq":1},{"date":"2014-07-29","iso":"3200","Freq":0}];
  
  return drawChart(opts,data);
  
  function drawChart(opts, data){ 
    var subCharts = [];
    
    var c = null;
    var assignedColors = {};
    
      //move this to top or make function since duplicated
    //allow manipulation of default colors to use with dimple
    if(opts.defaultColors.length) {
      defaultColorsArray = [];
      if (typeof(opts.defaultColors) == "function") {
        //assume this is a d3 scale
        //if there is a domain for the color scale given
        //then we will need to assign colors with dimples assignColor
        if( opts.defaultColors.domain().length > 0 ){
          defaultColorsArray = opts.defaultColors.range();
          opts.defaultColors.domain().forEach( function( d, i ) {
            assignedColors[d] = new dimple.color(opts.defaultColors.range()[i])
          })
        } else {
          for (var n=0;n<opts.defaultColors.range().length;n++) {
            defaultColorsArray.push(opts.defaultColors(n));
          };
        }
      } else {
        defaultColorsArray = opts.defaultColors;
      }
  
      
      //if colors not assigned with no keys and opts.groups
      if (!(Object.keys(assignedColors).length) & Boolean(opts.groups)) {
        //let's just assign colors in order with each unique
        //this is important if facetting where need colors assigned
        //if not in all pairs
        opts.groups = (typeof opts.groups == "string") ? [opts.groups] : opts.groups;
        d3.set(
          data.map(function(d){
            //dimple colors by last item in groups
            return d[opts.groups[opts.groups.length-1]]
          })
        ).values().forEach(function(u,i){
          //u will be our uniqe and will pick color from defaultColorsArray
          //console.log([u,defaultColorsArray[i]].concat());
          assignedColors[u] = new dimple.color(defaultColorsArray[i % defaultColorsArray.length])
        })
      }
    }
  
    
    //do series
    //set up a function since same for each
    //as of now we have x,y,groups,data,type in opts for primary layer
    //and other layers reside in opts.layers
    function buildSeries(layer, hidden, myChart){
      //inherit from primary layer if not intentionally changed or xAxis, yAxis, zAxis null
      if (!layer.xAxis) layer.xAxis = opts.xAxis;    
      if (!layer.yAxis) layer.yAxis = opts.yAxis;
      if (!layer.zAxis) layer.zAxis = opts.zAxis;
      
      var x = buildAxis("x", layer, myChart);
      x.hidden = hidden;
      
      var y = buildAxis("y", layer, myChart);
      y.hidden = hidden;
      
      //z for bubbles
      var z = null;
      if (!(typeof(layer.zAxis) === 'undefined') && layer.zAxis.type){
        z = buildAxis("z", layer, myChart);
      };
      
      //here think I need to evaluate group and if missing do null
      //as the group argument
      //if provided need to use groups from layer
      var s = new dimple.series(myChart, null, x, y, z, c, dimple.plot[layer.type], dimple.aggregateMethod.avg, dimple.plot[layer.type].stacked);
      
      //as of v1.1.4 dimple can use different dataset for each series
      if(layer.data){
        //convert to an array of objects
        var tempdata;
        //avoid lodash for now
        datakeys = d3.keys(layer.data)
        tempdata = layer.data[datakeys[1]].map(function(d,i){
          var tempobj = {}
          datakeys.forEach(function(key){
            tempobj[key] = layer.data[key][i]
          })
          return tempobj
        })
        s.data = tempdata;
      }
      
      if(layer.hasOwnProperty("groups")) {
        s.categoryFields = (typeof layer.groups === "object") ? layer.groups : [layer.groups];
        //series offers an aggregate method that we will also need to check if available
        //options available are avg, count, max, min, sum
      }
      if (!(typeof(layer.aggregate) === 'undefined')) {
        s.aggregate = eval(layer.aggregate);
      }
      if (!(typeof(layer.lineWeight) === 'undefined')) {
        s.lineWeight = layer.lineWeight;
      }
      if (!(typeof(layer.barGap) === 'undefined')) {
        s.barGap = layer.barGap;
      }    
      if (!(typeof(layer.interpolation) === 'undefined')) {
        s.interpolation = layer.interpolation;
      }     
     /* if (!(typeof(layer.eventHandler) === 'undefined')) {
        layer.eventHandler = (layer.eventHandler.length === "undefined") ? layer.eventHandler : [layer.eventHandler];
        layer.eventHandler.forEach(function(evt){
          s.addEventHandler(evt.event, eval(evt.handler))
        })
      }*/
        
      myChart.series.push(s);
      
      /*placeholder fix domain of primary scale for new series data
      //not working right now but something like this
      //for now just use overrideMin and overrideMax from rCharts
      for( var i = 0; i<2; i++) {
        if (!myChart.axes[i].overrideMin) {
          myChart.series[0]._axisBounds(i==0?"x":"y").min = myChart.series[0]._axisBounds(i==0?"x":"y").min < s._axisBounds(i==0?"x":"y").min ? myChart.series[0]._axisBounds(i==0?"x":"y").min : s._axisBounds(i==0?"x":"y").min;
        }
        if (!myChart.axes[i].overrideMax) {  
          myChart.series[0]._axisBounds(i==0?"x":"y")._max = myChart.series[0]._axisBounds(i==0?"x":"y").max > s._axisBounds(i==0?"x":"y").max ? myChart.series[0]._axisBounds(i==0?"x":"y").max : s._axisBounds(i==0?"x":"y").max;
        }
        myChart.axes[i]._update();
      }
      */
      
      return myChart;
    };
  
      
    //function to build axes
    function buildAxis(position, layer, myChart){
      var axis;
      var axisopts = opts[position+"Axis"];
      
      if(axisopts.measure) {
        axis = myChart[axisopts.type](position,layer[position],axisopts.measure);
      } else {
        axis = myChart[axisopts.type](position, layer[position]);
      };
      if(!(axisopts.type === "addPctAxis")) axis.showPercent = axisopts.showPercent;
      if (axisopts.orderRule) axis.addOrderRule(axisopts.orderRule);
      if (axisopts.grouporderRule) axis.addGroupOrderRule(axisopts.grouporderRule);  
      if (axisopts.overrideMin) axis.overrideMin = axisopts.overrideMin;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.overrideMax) axis.overrideMax = axisopts.overrideMax;
      if (axisopts.inputFormat) axis.dateParseFormat = axisopts.inputFormat;
      if (axisopts.outputFormat) axis.tickFormat = axisopts.outputFormat;    
      return axis;
    };
        
        
  
    //if facet not provided for x or y make Dummy variable
    //handle NULL facet
    if (typeof opts.facet == "undefined") opts.facet = {}
    opts.facet.x = opts.facet.x ? opts.facet.x : "Dummy"
    opts.facet.y = opts.facet.y ? opts.facet.y : "Dummy"    
    if(opts.facet.x === "Dummy" || opts.facet.y === "Dummy") {
      data.forEach(function(d){
        d.Dummy = 1;
      })
    }
  
    var rows = d3.set(data.map(function(d){return d[opts.facet.y]})).values();
    var nrow = opts.facet.nrow ? opts.facet.nrow : rows.length;
    var cols = d3.set(data.map(function(d){return d[opts.facet.x]})).values()
    var ncol = opts.facet.ncol ? opts.facet.ncol : cols.length;
    
    var tuples = d3.merge(rows.map(function(row,irow){return cols.map(function(col,icol){return {key:row + "~" + col, values: {"row":irow, "col":icol} }})}))
      
    var grid = d3.layout.grid()
      .rows( nrow )
      .cols( ncol )
      .size([ opts.width, opts.height-100])
      .bands();
    
    var svgGrid = d3.select("#" + opts.id).append("svg")
      .attr("width", opts.width)
      .attr("height", opts.height);
     // .attr("transform", "translate(50,0)");
  
    grid(tuples);
  
  /* var cells = d3.select("#" + opts.id).selectAll("svg")
      .data(grid(tuples))
      .enter()
        .append("svg")
          .attr("class", "cell")
          .attr("id", function(d) {
            return d.key;
          })
          .attr("transform", function(d, i) {
             return "translate(" + d.x + "," + d.y + ")"
           })
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1]);
  
    var color = d3.scale.linear()
      .domain([0, 3, 6])
      .range(["red", "lightgray", "green"]);
      
  /*  cells.selectAll("rect")
      .data(function(d){
        return [d];
      })
        .enter().append("rect")
          .attr("width", grid.nodeSize()[0])
          .attr("height", grid.nodeSize()[1])
          .style("fill", function(d) {return color(d.values.row)});         
  */
      tuples.forEach(function(cell,cellnum) {
          //cell = d3.select(cell);
      
          // Filter the data set for the quarter and the price tier
          // of the current shape
          var filteredData = dimple.filterData(data, opts.facet.x, cell.key.split('~')[1]);
          filteredData = dimple.filterData(filteredData, opts.facet.y, cell.key.split('~')[0]);    
          
          // Draw a new chart which will go in the current shape
          var subChart = new dimple.chart(svgGrid, filteredData);
  
          if (tuples.length > 1){
            // Position the chart inside the shape
            subChart.height = grid.nodeSize()[1]
            subChart.width = grid.nodeSize()[0]      
            
            if (opts.margins) {
              subChart.setBounds(
                parseFloat(cell.x + opts.margins.left),
                parseFloat(cell.y + opts.margins.top),
                subChart.width - opts.margins.right- opts.margins.left,
                subChart.height - opts.margins.top - opts.margins.bottom
              )
            } else {
              subChart.setBounds(
                parseFloat(cell.x + 50), 
                parseFloat(cell.y + 10),
                parseFloat(grid.nodeSize()[0] - 50),
                parseFloat(grid.nodeSize()[1]) - 10
              );
            }  
          } else { //only one chart
            if (opts.bounds) {
              subChart.setBounds(opts.bounds.x, opts.bounds.y, opts.bounds.width, opts.bounds.height);//myChart.setBounds(80, 30, 480, 330);
            }
          }
          
            //dimple allows use of custom CSS with noFormats
            if(opts.noFormats) { subChart.noFormats = opts.noFormats; };
            
            //need to fix later for better colorAxis support
            if(d3.keys(opts.colorAxis).length > 0) {
              c = subChart[opts.colorAxis.type](opts.colorAxis.colorSeries,opts.colorAxis.palette) ;
              if(opts.colorAxis.outputFormat){
                c.tickFormat = opts.colorAxis.outputFormat;
              }
            }
          
            //add the colors from the array into the chart's defaultColors
            if (typeof defaultColorsArray != "undefined"){
              subChart.defaultColors = defaultColorsArray.map(function(d) {
                return new dimple.color(d);
              });          
            }
            subChart._assignedColors = assignedColors;
            
            subChart = buildSeries(opts, false, subChart);
            if (opts.layers.length > 0) {
              opts.layers.forEach(function(layer){
                subChart = buildSeries(layer, true, subChart);
              })
            }
          
            //unsure if this is best but if legend is provided (not empty) then evaluate
            if(d3.keys(opts.legend).length > 0) {
              var l =subChart.addLegend();
              d3.keys(opts.legend).forEach(function(d){
                l[d] = opts.legend[d];
              });
            }
            //quick way to get this going but need to make this cleaner
            if(opts.storyboard) {
              subChart.setStoryboard(opts.storyboard);
            };
            
            //catch all for other options
            //these can be provided by dMyChart$chart( ... )
              
            
            //add facet row and column in case we need later
            subChart.facetposition = cell.values;
            
            subCharts.push(subChart);
          })
  
      subCharts.forEach(function(subChart) {
        subChart.draw();
      })
    
    //get rid of all y for those not in column 1
    //can easily customize this to only remove bits and pieces
    if(opts.facet.removeAxes) {
      ["x","y","z"].forEach(function(position){
        //work on axis scaling
        //assume if remove then same scales for all charts
        axisdomain = [];      
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axisdomain.push(axis._scale.domain())
            }
          })
        });
        axisdomain = d3.extent([].concat.apply([], axisdomain));
        subCharts.forEach(function(subChart){
          subChart.axes.forEach(function(axis){
            if (axis.position === position && !axis._hasCategories()){
              axis.overrideMin = axisdomain[0];
              axis.overrideMax = axisdomain[1];
            }
          })
          subChart.draw(null,true)
        });
      })
      
      //evaluate which do not fall in column 1 or row 1 to remove
      var xpos = d3.extent(subCharts,function(d){return d.x});
      var ypos = d3.extent(subCharts,function(d){return d.y});    
      subCharts.filter(function(d){
        return d.x!=xpos[0];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }
        d.axes.forEach(function(axis){
          if (axis.position === "y"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
      //now x for those not in row 1
      subCharts.filter(function(d){
        return d.y!=ypos[1];
      }).forEach(function(d){
        d.series[0]._dropLineOrigin = function(){
          return {"x" : xpos[0],"y" : ypos[1] + d._heightPixels()}
        }        
        d.axes.forEach(function(axis){
          if (axis.position === "x"){
            //leave there for reference but set opacity 0
            if (axis.shapes) axis.shapes.style("opacity",0);
            if (axis.titleShape) axis.titleShape.style("opacity",0);
          }
        })
      });
    }
  return subCharts;
  }
})();
</script>
<script></script>


```r
iso %:>% dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = .,
  type = "area",
  height = 400,
  width =600
  ,xAxis = list( grouporderRule = sort( .$iso ) )
  ,defaultColors = tol4qualitative 
) %:>% .$show("inline")
```

As you might already know, I love R, especially with [rCharts](http://rcharts.io) and [slidify](http://slidify.org).

Now I can add that I love [httr](http://github.com/hadley/dplyr) and [pipeR](http://renkun.me/blog/2014/07/26/difference-between-magrittr-and-pipeR.html).

Thanks to all those who contributed knowingly and unknowingly to this post.


