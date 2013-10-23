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

# Flickr Interesting ISOs with Rflickr & rCharts + slidify




The information available from [the Flickr API](http://www.flickr.com/services/api/) is incredibly rich.  This Atlantic article [This is the World on Flickr](http://www.theatlantic.com/technology/archive/2013/10/this-is-the-world-on-flickr/280697/) motivated me to open up R and do some analysis on the [Flickr Explore](http://www.flickr.com/explore) list.  As you might expect, I'll be using my new favorite tools [`rCharts`](http://rcharts.io) and [`slidify`](http://slidify.org), and I will add one I have not mentioned [`Rflickr`](http://www.omegahat.org/Rflickr/).

### ISO Speed Popularity
I have always wondered what ISO speeds occur most frequently on Explore.  I never imagined that I could answer my question with R.  As usual, we will start by loading all the necessary packages.


```r
# analyze EXIF data for interesting list
library(lubridate)
#if you have not installed Rflickr
#install.packages("Rflickr", repos = "http://www.omegahat.org/R", type="source")
library(Rflickr)
data(FlickrFunctions)
```


If you do not have a free noncommercial API key, apply for one [here](http://www.flickr.com/services/api/keys/).  Trust me it is very easy, so don't let this be an excuse not to try it out.  I put mine in a little `secrets.Rdata` file that I will load with following code and then start a session.



```r
load("secrets.Rdata")

tok = authenticate(api_key, secret)

s <- flickrSession(secret, tok, api_key)
```


Since this is more a proof of concept rather than an ambitious scientific study, I'll just look back three days.


```r
#use this to specify how many days to analyze
daysAnalyze = 3
```


My code gets a little sloppy here but it does work.  Sorry for all the `lapply`.  I hope my comments will help you understand each of the steps.


```r
#initialize a data frame to collect 
df <- data.frame()
for(i in 1:daysAnalyze) {
  interesting <- s$flickr.interestingness.getList(date=as.character(today()-ddays(i)))
  print(today()-ddays(i))  #debug print what day we are getting
  print(length(interesting)) #debug print the count of photos
  #for each photo try to get the exif information
  #Flickr allows users to block EXIF
  #so use try to bypass error
  exifData <- lapply( 
    1:length(interesting),
    function(x){
      exif <- try(s$flickr.photos.getExif(interesting[[x]]["id"]))
      if (inherits(exif, "try-error")) exif = NA
      return(exif)
    }
  )
  
  #now that we have a list of EXIF for each photo
  #that allows it
  #use another lapply
  #to extract the useful information
  exifData.df <- lapply(
    exifData,
    function(x){
      if (!(is.na(x))) {
        exif.df <- do.call(rbind,lapply(
          1:(length(x)-1),
          function(y) {
            df <- data.frame(
              t(
                data.frame(
                  x[[y]][".attrs"]
                )
              ),
              x[[y]]["raw"],
              stringsAsFactors = FALSE
            )
            rownames(df)<-y
            if("clean" %in% names(x[[y]])) {
              df$clean = x[[y]]["clean"]
            } else df$clean = NA
            return(as.vector(df))
          })
        )
      } else exif.df <- rep(NA,5)
      return(exif.df)
    }
  )
  
  #one more lapply to just get the ISO speed if available
  isospeeds <- unlist(lapply(
    exifData.df,
    function(x){
      if(!(is.na(x))) {
        iso = x[which(x[,"label"]=="ISO Speed"),"raw"]
      } else iso = NA
      return(as.numeric(iso))
    }
  ))
  
  #make one data.frame with a Frequency(count) of ISO speeds
  df <- rbind(
    df,
    data.frame(
      as.character(today()-ddays(i)),
      table(isospeeds)
    )
  )
}
```

[1] "2013-10-22"
[1] 101
[1] "2013-10-21"
[1] 101
[1] "2013-10-20"
[1] 101

```r
#name columns for our df data.frame
colnames(df) <- c("date","iso","Freq")
#get rid of factors
#thanks http://stackoverflow.com/questions/3418128/how-to-convert-a-factor-to-an-integer-numeric-without-a-loss-of-information
df$iso <- as.character(levels(df$iso))[df$iso]
```



### Plot Our Results

Now that we have a `data.frame` with ISO speeds, let's use `rCharts` to analyze it.  I will use [`dimplejs`](http://dimplejs.org).



```r
require(rCharts)
dIso <- dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = df,
  type = "bar"
)
dIso$xAxis( orderRule = "iso" )
dIso
```

<iframe src=assets/fig/unnamed-chunk-6.html seamless></iframe>



```r
dIso <- dPlot(
  y = "Freq",
  x = c("iso","date"),
  groups = "date",
  data = df,
  type = "bar"
)
dIso$xAxis( orderRule = "iso" )
dIso
```

<iframe src=assets/fig/unnamed-chunk-7.html seamless></iframe>



```r
dIso <- dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = df,
  type = "bar"
)
dIso$xAxis( grouporderRule = "iso" )
dIso
```

<iframe src=assets/fig/unnamed-chunk-8.html seamless></iframe>



```r
dIso <- dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = df,
  type = "line"
)
dIso$xAxis( orderRule = "iso" )
dIso
```

<iframe src=assets/fig/unnamed-chunk-9.html seamless></iframe>



```r
dIso <- dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = df,
  type = "area"
)
dIso$xAxis( grouporderRule = "iso" )
dIso
```

<iframe src=assets/fig/unnamed-chunk-10.html seamless></iframe>

