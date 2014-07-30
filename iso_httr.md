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


<div class = "well">
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
I will incorporate the original text into the content below.
</p>
</div>

The information available from [the Flickr API](http://www.flickr.com/services/api/) is incredibly rich.  This Atlantic article [This is the World on Flickr](http://www.theatlantic.com/technology/archive/2013/10/this-is-the-world-on-flickr/280697/) motivated me to open up R and do some analysis on the [Flickr Explore](http://www.flickr.com/explore) list.  As you might expect, I'll be using my new favorite tools [`rCharts`](http://rcharts.io) and [`slidify`](http://slidify.org).

### ISO Speed Popularity
I have always wondered what ISO speeds occur most frequently on Explore.  I never imagined that I could answer my question with R.  As usual, we will start by loading all the necessary packages.


```r
# analyze EXIF data for interesting list
library(httr)
library(pipeR)
library(jsonlite)
```

If you do not have a free noncommercial API key, apply for one [here](http://www.flickr.com/services/api/keys/).  Trust me it is very easy, so don't let this be an excuse not to try it out.  I put mine in a little `secrets.Rdata` file that I will load with following code and then start a session.



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


```r
#initialize a data frame to collect 
interesting <- lapply(1:daysAnalyze, function(i){
    interesting <- GET(url=sprintf(
      "https://api.flickr.com/services/rest/?method=flickr.interestingness.getList&api_key=%s&date=%s&format=json&nojsoncallback=1"
      , api_key
      , format( Sys.Date() - i, "%Y-%m-%d")
      , tok$credentials$oauth_token
      )
    ) %>>%
      content( as = "text" ) %>>%
      jsonlite::fromJSON () %:>%
      .$photos$photo %>>%
      return
  }
)
```

<h5>Get EXIF for the Interesting</h5>
  

```r
  #for each photo try to get the exif information
  #Flickr allows users to block EXIF
  #so use try to bypass error
  exifData <- lapply( 
    1:nrow(interesting$photos$photo),
    function(x){
      exif <- try(
        GET(url=sprintf(
          "https://api.flickr.com/services/rest/?method=flickr.photos.getExif&api_key=%s&photo_id=%s&secret=%s&format=json&nojsoncallback=1"
          , api_key
          , interesting$photos$photo$id[x]
          , interesting$photos$photo$secret[x]
          )
        ) %>>%
          content( as = "text" ) %>>%
          jsonlite::fromJSON ()
      )
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
  
  #think we can eliminate the above since we will get a df straight from the json
  # so for each exif in list get the exif data.frame and find ISO
  x<-exif[[1]]$exif
  
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
#name columns for our df data.frame
colnames(df) <- c("date","iso","Freq")
#get rid of factors
#thanks http://stackoverflow.com/questions/3418128/how-to-convert-a-factor-to-an-integer-numeric-without-a-loss-of-information
df$iso <- as.character(levels(df$iso))[df$iso]
```


### Plot Our Results

Now that we have a `data.frame` with ISO speeds, let's use `rCharts` to analyze it.  I will use [`dimplejs`](http://dimplejs.org).



```r
# Thanks to http://tradeblotter.wordpress.com/
# Qualitative color schemes by Paul Tol
 tol4qualitative=c("#4477AA", "#117733", "#DDCC77", "#CC6677")

require(rCharts)
dIso <- dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = df,
  type = "bar",
  height = 400,
  width =600
)
dIso$xAxis( orderRule = "iso" )
dIso$defaultColors(
  #"#! d3.scale.category10() !#", 
  tol4qualitative,
  replace = T
)
dIso
```


```r
dIso <- dPlot(
  y = "Freq",
  x = c("iso","date"),
  groups = "date",
  data = df,
  type = "bar",
  height = 400,
  width =600
)
dIso$xAxis( orderRule = "iso" )
dIso$defaultColors(
  #"#! d3.scale.category10() !#", 
  tol4qualitative,
  replace = T
)
dIso
```


```r
dIso <- dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = df,
  type = "bar",
  height = 400,
  width =600
)
dIso$xAxis( grouporderRule = "iso" )
dIso$defaultColors(
  #"#! d3.scale.category10() !#", 
  tol4qualitative,
  replace = T
)
dIso
```


```r
dIso <- dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = df,
  type = "line",
  height = 400,
  width =600
)
dIso$xAxis( orderRule = "iso" )
dIso$defaultColors(
  #"#! d3.scale.category10() !#", 
  tol4qualitative,
  replace = T
)
dIso
```


```r
dIso <- dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = df,
  type = "area",
  height = 400,
  width =600
)
dIso$xAxis( grouporderRule = "iso" )
dIso$defaultColors(
  #"#! d3.scale.category10() !#", 
  tol4qualitative,
  replace = T
)
dIso
```

As you might already know, I love R, especially with [rCharts](http://rcharts.io) and [slidify](http://slidify.org).
