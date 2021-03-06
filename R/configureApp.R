#' Configure an Application
#'
#' Configure an application running on a remote server.
#'
#' @inheritParams deployApp
#'
#' @param appName Name of application to configure
#' @param appDir Directory containing application. Defaults to
#'   current working directory.
#' @param account Account name. If a single account is registered on the
#'   system then this parameter can be omitted.
#' @param server Server name. Required only if you use the same account name on
#'   multiple servers (see [servers()])
#' @param redeploy Re-deploy application after its been configured.
#' @param size Configure application instance size
#' @param instances Configure number of application instances
#' @examples
#' \dontrun{
#'
#' # set instance size for an application
#' configureApp("myapp", size="xlarge")
#' }
#' @seealso [applications()], [deployApp()]
#' @export
configureApp <- function(appName, appDir=getwd(), account = NULL, server = NULL,
                         redeploy = TRUE, size = NULL,
                         instances = NULL, logLevel = c("normal", "quiet", "verbose")) {

  # resolve target account and application
  accountDetails <- accountInfo(resolveAccount(account, server), server)
  application <- resolveApplication(accountDetails, appName)

  displayStatus <- displayStatus(identical(logLevel, "quiet"))

  # some properties may required a rebuild to take effect
  rebuildRequired = FALSE

  # get a list of properties to set
  properties <- list()
  if (! is.null(size) ) {
    properties[[ "application.instances.template" ]] = size
  }
  if (! is.null(instances) ) {
    properties[[ "application.instances.count" ]] = instances
  }

  # set application properties
  serverDetails <- serverInfo(accountDetails$server)
  client <- clientForAccount(accountDetails)
  for (i in names(properties)) {
    propertyName <- i
    propertyValue <- properties[[i]]

    # dispatch to the appropriate client implementation
    if (is.function(client$configureApplication))
      client$configureApplication(application$id, propertyName, propertyValue)
    else if (is.function(client$setApplicationProperty))
      client$setApplicationProperty(application$id, propertyName, propertyValue)
    else
      stop("Server ", accountDetails$server, " has no appropriate configuration method.")
  }

  # redeploy application if requested
  if (redeploy) {
    if (length(properties) > 0) {
      deployApp(appDir=appDir, appName=appName, account=account, logLevel=logLevel, upload=rebuildRequired)
    }
    else
    {
      displayStatus("No configuration changes to deploy")
    }
  }
}

#' Set Application property
#'
#' Set a property on currently deployed ShinyApps application.
#'
#' @param propertyName Name of property to set
#' @param propertyValue Nalue to set property to
#' @param appName Name of application
#' @param appPath Directory or file that was deployed. Defaults to current
#'   working directory.
#' @param account Account name. If a single account is registered on the system
#'   then this parameter can be omitted.
#' @param force Forcibly set the property
#'
#' @note This function only works for ShinyApps servers.
#'
#' @examples
#' \dontrun{
#'
#' # set instance size for an application
#' setProperty("application.instances.count", 1)
#'
#' # disable application package cache
#' setProperty("application.package.cache", FALSE)
#'
#' }
#' @export
setProperty <- function(propertyName, propertyValue, appPath = getwd(),
                        appName = NULL, account = NULL, force = FALSE) {

  # resolve the application target and target account info
  target <- deploymentTarget(appPath, appName, NULL, NULL, account)
  accountDetails <- accountInfo(target$account)
  serverDetails <- serverInfo(accountDetails$server)
  lucid <- lucidClient(serverDetails$url, accountDetails)
  application <- getAppByName(lucid, accountDetails, target$appName)
  if (is.null(application))
    stop("No application found. Specify the application's directory, name, ",
         "and/or associated account.")

  invisible(lucid$setApplicationProperty(application$id,
                                         propertyName,
                                         propertyValue,
                                         force))
}

#' Unset Application property
#'
#' Unset a property on currently deployed ShinyApps application (restoring to
#' its default value)
#'
#' @param propertyName Name of property to unset
#' @param appName Name of application
#' @param appPath Directory or file that was deployed. Defaults to current
#'   working directory.
#' @param account Account name. If a single account is registered on the system
#'   then this parameter can be omitted.
#' @param force Forcibly unset the property
#'
#' @note This function only works for ShinyApps servers.
#'
#' @examples
#' \dontrun{
#'
#' # unset application package cache property to revert to default
#' unsetProperty("application.package.cache")
#'
#' }
#' @export
unsetProperty <- function(propertyName, appPath = getwd(), appName=NULL,
                          account = NULL, force=FALSE) {

  # resolve the application target and target account info
  target <- deploymentTarget(appPath, appName, NULL, NULL, account)
  accountDetails <- accountInfo(target$account)
  serverDetails <- serverInfo(accountDetails$server)
  lucid <- lucidClient(serverDetails$url, accountDetails)
  application <- getAppByName(lucid, accountInfo, target$appName)
  if (is.null(application))
    stop("No application found. Specify the application's directory, name, ",
         "and/or associated account.")

  invisible(lucid$unsetApplicationProperty(application$id,
                                           propertyName,
                                           force))
}


#' Show Application property
#'
#' Show propreties of an application deployed to ShinyApps.
#'
#' @param appName Name of application
#' @param appPath Directory or file that was deployed. Defaults to current
#'   working directory.
#' @param account Account name. If a single account is registered on the
#'   system then this parameter can be omitted.
#'
#' @note This function works only for ShinyApps servers.
#'
#' @export
showProperties <- function(appPath = getwd(), appName = NULL, account = NULL) {

  # determine the log target and target account info
  target <- deploymentTarget(appPath, appName, NULL, NULL, account)
  accountDetails <- accountInfo(target$account)
  serverDetails <- serverInfo(accountDetails$server)
  lucid <- lucidClient(serverDetails$url, accountDetails)
  application <- getAppByName(lucid, accountDetails, target$appName)
  if (is.null(application))
    stop("No application found. Specify the application's directory, name, ",
         "and/or associated account.")

  # convert to data frame
  res <- do.call(rbind, application$deployment$properties)
  df <- as.data.frame(res, stringsAsFactors = FALSE)
  names(df) <- c("value")
  return(df)
}
