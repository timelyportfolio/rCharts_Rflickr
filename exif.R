


# analyze EXIF data for interesting list

require(lubridate)
require(Rflickr)
data(FlickrFunctions)

load("secrets.Rdata")

tok = authenticate(api_key, secret)
flickr.tags.getHotList(secret, tok, api_key)    

s <- flickrSession(secret, tok, api_key)

daysAnalyze = 3

df <- data.frame()

for(i in 1:daysAnalyze) {
  interesting <- s$flickr.interestingness.getList(date=as.character(today()-ddays(i)))
  print(today()-ddays(i))
  print(length(interesting))
  exifData <- lapply(
    1:length(interesting),
    function(x){
      exif <- try(s$flickr.photos.getExif(interesting[[x]]["id"]))
      if (inherits(exif, "try-error")) exif = NA
      return(exif)
    }
  )
  
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
  
  isospeeds <- unlist(lapply(
    exifData.df,
    function(x){
      if(!(is.na(x))) {
        iso = x[which(x[,"label"]=="ISO Speed"),"raw"]
      } else iso = NA
      return(as.numeric(iso))
    }
  ))
  

  df <- rbind(
    df,
    data.frame(
      as.character(today()-ddays(i)),
      table(isospeeds)
    )
  )
}
#name columns
colnames(df) <- c("date","iso","Freq")
#get rid of factors
#thanks http://stackoverflow.com/questions/3418128/how-to-convert-a-factor-to-an-integer-numeric-without-a-loss-of-information
df$iso <- as.character(levels(df$iso))[df$iso]

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

dIso <- dPlot(
  y = "Freq",
  x = c("iso","date"),
  groups = "date",
  data = df,
  type = "bar"
)
dIso$xAxis( orderRule = "iso" )
dIso

dIso <- dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = df,
  type = "bar"
)
dIso$xAxis( grouporderRule = "iso" )
dIso


dIso <- dPlot(
  y = "Freq",
  x = "iso",
  groups = "date",
  data = df,
  type = "line"
)
dIso$xAxis( orderRule = "iso" )
dIso


dIso <- dPlot(
  y = "Freq",
  x = c("date","iso"),
  groups = "date",
  data = df,
  type = "area"
)
dIso$xAxis( grouporderRule = "iso" )
dIso
