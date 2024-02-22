# tmcpull

Really quick usage:

./tmcpull.sh --reqs
find csvkit

./tmcpull.sh --tkg
list all tkg's managed by tmc

./tmcpull.sh --tkc
list all tkc's managed by tmc

./tmcpull.sh --tkr
list all clusters by version

./tmcpull.sh --tkcall
list all tkc's managed by tmc with env column

add --csv for csv output
add --csv --look to convert csv to a table (that is markdown compatible)

assumes you've already logged into tmc via api token.  Try `tanzu login`

feel free to make suggestions for other tables that the command `tanzu mission-control --help` can pull
