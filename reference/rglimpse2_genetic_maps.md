# Resolve packaged GRCh37 or GRCh38 genetic maps

`rglimpse2_genetic_map()` resolves one absolute installed map path.
`rglimpse2_genetic_maps()` returns the complete packaged inventory. The
autosomal and chromosome X files are byte-identical copies from the
pinned GLIMPSE source tree. The Y non-PAR and mitochondrial files are
derived two-anchor, zero-recombination coordinate maps, not empirical
maps.

## Usage

``` r
rglimpse2_genetic_maps()

rglimpse2_genetic_map(assembly = "GRCh38", chromosome, region = character())
```

## Arguments

- assembly:

  Reference assembly, either `"GRCh37"` or `"GRCh38"`.

- chromosome:

  One autosome named `"1"` through `"22"`, `"X"`, `"Y"`, or `"MT"`. A
  leading `"chr"` is accepted; `"M"` is normalized to `"MT"`.

- region:

  Empty to select the chromosome default, or one of `"full"`,
  `"nonpar"`, `"par1"`, or `"par2"`. The default is `"nonpar"` for X and
  Y and `"full"` otherwise.

## Value

`rglimpse2_genetic_map()` returns one absolute file path.
`rglimpse2_genetic_maps()` returns a data frame describing every map and
its absolute installed path.

## Examples

``` r
rglimpse2_genetic_map("GRCh38", "22")
#> [1] "/home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b38/chr22.b38.gmap.gz"
rglimpse2_genetic_map("GRCh37", "Y")
#> [1] "/home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chrY.b37.gmap.gz"
rglimpse2_genetic_map("GRCh38", "MT")
#> [1] "/home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b38/chrMT.b38.gmap.gz"
head(rglimpse2_genetic_maps())
#>   assembly chromosome region      kind start_bp    end_bp start_cm   end_cm
#> 1   GRCh37          1   full empirical    55550 249218992        0 286.2792
#> 2   GRCh37          2   full empirical    12994 243090997        0 268.8396
#> 3   GRCh37          3   full empirical    61113 197874528        0 223.3611
#> 4   GRCh37          4   full empirical    12906 191028645        0 214.6885
#> 5   GRCh37          5   full empirical    20583 180715810        0 204.0894
#> 6   GRCh37          6   full empirical    92012 171051316        0 192.0399
#>   entries                              file                  source
#> 1  256895 genetic_maps.b37/chr1.b37.gmap.gz GLIMPSE-pinned-upstream
#> 2  286355 genetic_maps.b37/chr2.b37.gmap.gz GLIMPSE-pinned-upstream
#> 3  223360 genetic_maps.b37/chr3.b37.gmap.gz GLIMPSE-pinned-upstream
#> 4  211115 genetic_maps.b37/chr4.b37.gmap.gz GLIMPSE-pinned-upstream
#> 5  215414 genetic_maps.b37/chr5.b37.gmap.gz GLIMPSE-pinned-upstream
#> 6  234422 genetic_maps.b37/chr6.b37.gmap.gz GLIMPSE-pinned-upstream
#>                                md5
#> 1 15f098ee8a9f803657608559eef3bc2a
#> 2 20b2a865e5d04daf5d0c5422934bf1ac
#> 3 53e7da0e5a2f4bb96007fd57f46dfa4d
#> 4 ff22f04a9120ae90a185f6926b7ff4bf
#> 5 c04e073550d715ce52ae35070b241080
#> 6 4d30099024d5f233002d06452a02f1f0
#>                                                                                       path
#> 1 /home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chr1.b37.gmap.gz
#> 2 /home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chr2.b37.gmap.gz
#> 3 /home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chr3.b37.gmap.gz
#> 4 /home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chr4.b37.gmap.gz
#> 5 /home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chr5.b37.gmap.gz
#> 6 /home/runner/work/_temp/Library/RGlimpse2/genetic_maps/genetic_maps.b37/chr6.b37.gmap.gz
```
