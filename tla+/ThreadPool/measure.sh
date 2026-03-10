# remove old results
rm -f times.txt

# run 100 times, append elapsed seconds to times.txt
for i in $(seq 1 100); do
  /usr/bin/time -f "%e" -o times.txt -a ./thread-pool
done

# compute mean, median, stddev using awk
awk '
{ a[NR] = $1; s += $1 }
END {
  n = NR
  if (n==0) { print "no samples"; exit }
  mean = s/n
  asort(a)
  if (n % 2) median = a[(n+1)/2]
  else median = (a[n/2] + a[n/2+1])/2
  for (i=1;i<=n;i++) v += (a[i]-mean)^2
  sd = sqrt(v/n)
  printf "n=%d\nmean=%.6f s\nmedian=%.6f s\nstddev=%.6f s\n", n, mean, median, sd
}
' times.txt
