## TODO: combine ICE and ICE.centered, so that active binding can be used for both. 
##       anchoring will then wrapped in if-clause




#' Individual conditional expectations (ICE)
#' 
#' @description 
#' Fits and plots individual conditional expectation function on an arbitrary machine learning model
#' 
#' @details 
#' TODO
#' @template args_experiment_wrap
#' @param feature The index of the feature of interest.
#' @template arg_grid.size 
#' @param center.at The value for the centering of the plot. Numeric for numeric features, and the level name for factors.
#' @return An individual conditional expectation object
#' @examples
#' 
#' @seealso 
#' \code{\link{pdp}} for partial dependence plots.
#'
#' @importFrom dplyr left_join
#' @export
ice = function(object, X, feature, grid.size=10, center.at = NULL, class=NULL, ...){
  samp = DataSampler$new(X)
  pred = prediction.model(object, class = class, ...)
  
  obj = ICE$new(predictor = pred, sampler = samp, anchor.value = center.at,  feature = feature, grid.size = grid.size)
  obj$run()
  obj
}




ICE = R6Class('ICE',
  inherit = PDP,
  public = list( 
    initialize = function(feature, anchor.value = NULL, ...){
      assert_number(anchor.value, null.ok = TRUE)
      private$anchor.value = anchor.value
      assert_count(feature)
      super$initialize(feature=feature, ...)
    }
  ),
  private = list(
    generate.plot = function(){
      p = ggplot(private$results, mapping = aes_string(x = names(private$results)[1], y = 'y.hat', group = '..individual'))
      if(self$feature.type == 'numerical') p = p + geom_line()
      else if (self$feature.type == 'categorical') p = p + geom_line(alpha = 0.2) + geom_point()
      
      if(ncol(private$Q.results) > 1){
        p + facet_wrap("..class.name")
      } else {
        p
      }
    }, 
    intervene = function(){
      X.design = super$intervene()
      if(!is.null(private$anchor.value)) {
        X.design.anchor = private$X.sample
        X.design.anchor[self$feature.index] = private$anchor.value
        private$X.design.ids = c(private$X.design.ids, 1:nrow(private$X.sample))
        X.design = rbind(X.design, X.design.anchor)
      }
      X.design
    },
    aggregate = function(){
      X.id = private$X.design.ids
      X.results = private$X.design[self$feature.index]
      X.results$..individual = X.id
      if(ncol(private$Q.results) > 1){
        y.hat.names = colnames(private$Q.results)
        X.results = cbind(X.results, private$Q.results)
        X.results = gather(X.results, key = "..class.name", value = "y.hat", one_of(y.hat.names))
      } else {
        X.results['y.hat']= private$Q.results
        X.results['..class.name'] = 1
      }
      
      if(!is.null(private$anchor.value)){
        X.aggregated.anchor = X.results[X.results[self$feature.names] == private$anchor.value, c('y.hat', '..individual', '..class.name')]
        names(X.aggregated.anchor) = c('anchor.yhat', '..individual', '..class.name')
        X.results = left_join(X.results, X.aggregated.anchor, by = c('..individual', '..class.name'))
        X.results$y.hat = X.results$y.hat - X.results$anchor.yhat
        X.results$anchor.yhat = NULL
        X.results
      }
      
      X.results
    },
    anchor.value = NULL
  ),
  active = list(
    center.at = function(anchor.value){
      private$anchor.value = anchor.value
      private$flush()
    }
  )
)
