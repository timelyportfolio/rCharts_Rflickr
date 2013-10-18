#experiment with R and Flickr with Rflickr package from omegahat
#install.packages("Rflickr", repos = "http://www.omegahat.org/R", type="source")

require(Rflickr)
data(FlickrFunctions)

load("secrets.Rdata")

tok = authenticate(api_key, secret)
flickr.tags.getHotList(secret, tok, api_key)    

s <- flickrSession(secret, tok, api_key)
hotList <- list()
hotList$json <- s$getHotList(verbose = TRUE, format = 'json')
s$getHotList(verbose = TRUE, .convert = NA)
s$getHotList(verbose = TRUE, .convert = xmlRoot)  

interesting <- s$flickr.interestingness.getList()

s$getListPhoto(interesting[[1]]["id"])
s$flickr.photos.getInfo(interesting[[2]]["id"])
s$flickr.photos.getExif(interesting[[3]]["id"])


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

isospeeds <- lapply(
  exifData.df,
  function(x){
    if(!(is.na(x))) {
      iso = x[which(x[,"label"]=="ISO Speed"),"raw"]
    } else iso = NA
    return(as.numeric(iso))
  }
)