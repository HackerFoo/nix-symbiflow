# takes a filename, and a list of key=val args, and replaces these constants

file=$1
shift
expr=""

for s in "$@"
do
    a=(${s//=/ })
    expr="$expr -e 's/\(const.*\)\(${a[0]}\ *=\ *\)\(.*\);/\1\2${a[1]};/'"
done

eval "sed --in-place=.orig ${expr} ${file}"
diff -u ${file}.orig ${file} | tee -a constants.patch

exit 0
