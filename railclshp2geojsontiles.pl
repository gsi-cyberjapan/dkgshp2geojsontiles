use File::Find;
use File::Path;
use Math::Trig;
use utf8;
use Encode;
use Archive::Zip;
use Geo::ShapeFile;
use Data::Dumper;

## 設定 ##
###########################################################################################################
#出力するgeojson tileのzoomlevelを指定
my $zoom=16;
#shpのzipの置き場所を指定（この場所以下のzipを検索）
my $zipdir = 'D://shpzip/';
#取り出すshpのファイル名前に含まれる文字列
my $shpname = '-RailCL-';
#取り出したshpの置き場所
my $shpdir = 'D://railclshp/';
#geojsonのpropertiesへ出力するshpの属性項目の設定
my @outproperty = ('rID','lfSpanFr','lfSpanTo','tmpFlg','orgGILvl','ftCode','admCode','devDate','type','snglDbl','railState','lvOrder','staCode','rtCode');
#geojsonのpropertiesへ出力するshpの属性項目が文字列か数値かの判別（文字列：0、数値：1）
my %outproperty_num = ('rID' => 0,'lfSpanFr' => 0,'lfSpanTo' => 0,'tmpFlg' => 1,'orgGILvl' => 0,'ftCode' => 0,'admCode' => 0,'devDate' => 0,'type' => 0,'snglDbl' => 0,'railState' => 0,'lvOrder' => 1,'staCode' => 0,'rtCode' => 0);
###########################################################################################################


## 以下、プログラム ##
###########################################################################################################

%tlcnt=();#タイルリスト

##zip検索
print "zip search..\n";
#-- ディレクトリを指定（指定フォルダを指定） --#
@directories_to_searchzip = ($zipdir);
#-- 実行 --#
find(\&wantedzip, @directories_to_searchzip);

sub wantedzip{
#  $kariList = $File::Find::dir, '/';    #カレントディレクトリ  
  $kariList = $_;          #ファイル名
 #zipを検索
  if($kariList =~ /\.zip/ ){

   #オブジェクトを作成
   my $zip = Archive::Zip->new();
   #ファイルの読み込みに失敗したら強制終了
   die 'read error' unless $zip->read($kariList) == AZ_OK;
   #ファイルの一覧を取得
   @members = $zip->members();
   foreach (@members) {
   #ファイル名はfileNameにて取得できます。
    my $name = $_->fileName();
    if($name =~ /$shpname/){
     #ファイルをアーカイブから取り出すにはextractMemberもしくは以下のextractMemberWithoutPathsを使用します。
     $zip->extractMemberWithoutPaths($name,$shpdir.$name);
    }
   }

  }
}

##shp検索
print "shp search..\n";

#-- ディレクトリを指定（指定フォルダを指定） --#
@directories_to_searchshp = ($shpdir);
#-- 実行 --#
find(\&wantedshp, @directories_to_searchshp);

sub wantedshp{
#  $kariList = $File::Find::dir, '/';    #カレントディレクトリ  
  $kariList = $_;          #ファイル名
 #shpを検索
  if($kariList =~ /\.shp/ ){
   my @d= split(/\./,$kariList);

my $shapefile = new Geo::ShapeFile($d[0]);
for (1 ..$shapefile->shapes){
    my $shape = $shapefile->get_shp_record($_);
    my %data = $shapefile->get_dbf_record($_); 
    my @point = $shape->points;
    my @LB=();
    my @karip =();
    foreach my $p (@outproperty){
     if( defined $data{$p} && $data{$p} ne ""){
      $data{$p} = decode('cp932', $data{$p});
      if($outproperty_num{$p} == 1){
       push(@karip, "\"".$p."\":".$data{$p});
      }else{
       push(@karip, "\"".$p."\":\"".$data{$p}."\"");
      }
     }else{
      push(@karip, "\"".$p."\":\"\"");
     }
    }

    for (my $i=1; $i<@point; $i++) {
     my @tilexy1 = LB2XY($point[$i-1]->X,$point[$i-1]->Y,$zoom);
     my @tilexy2 = LB2XY($point[$i]->X,$point[$i]->Y,$zoom);
     
     #クリップ判定の前に、線分の最初の点がタイル座標上にある場合の処理（それ以前の点が別タイルかどうか判定）
     if( @LB >0){
      if($tilexy1[0] == int($tilexy1[0]) || $tilexy1[1] == int($tilexy1[1])){
        #print $point[$i-1]->X.",".$point[$i-1]->Y."\n";
        my $flag = 0;
        for (my $ii=0; $ii<@LB; $ii++) {
         $flag = CLIPMAE($LB[$ii]->[0],$LB[$ii]->[1],$tilexy2[0],$tilexy2[1]);
         if($flag==1){last;};
        }
        if($flag==1){
          push(@LB,[$point[$i-1]->X,$point[$i-1]->Y]);
          my $key=LB2XYTILE($zoom,@LB);
          my $kari="{ \"type\": \"Feature\",\"geometry\": {\"type\": \"LineString\", \"coordinates\": [";
          for (my $iii=0; $iii<@LB; $iii++) {
           if($iii==0){
            $kari=$kari."[".$LB[$iii]->[0].",".$LB[$iii]->[1]."]";
           }else{
            $kari=$kari.",[".$LB[$iii]->[0].",".$LB[$iii]->[1]."]";
           }
          }
          $kari=$kari."]},\"properties\": {".join(',', @karip)."}}";
          if ($tlcnt{$key}) {
           $tlcnt{$key}=$tlcnt{$key}.",\n".$kari;
          } else {
           $tlcnt{$key}=$kari;
          }
          @LB=();
        }
      }
     }
     
     #クリップ判定
     my @LB_clip = CLIPLINE($tilexy1[0],$tilexy1[1],$tilexy2[0],$tilexy2[1],$zoom);
     push(@LB,[$point[$i-1]->X,$point[$i-1]->Y]);
     if(@LB_clip>0){
      for (my $ii=0; $ii<@LB_clip; $ii++) {
        push(@LB,[$LB_clip[$ii]->[0],$LB_clip[$ii]->[1]]);
        my $key=LB2XYTILE($zoom,@LB);
        my $kari="{ \"type\": \"Feature\",\"geometry\": {\"type\": \"LineString\", \"coordinates\": [";
        for (my $iii=0; $iii<@LB; $iii++) {
         if($iii==0){
          $kari=$kari."[".$LB[$iii]->[0].",".$LB[$iii]->[1]."]";
         }else{
          $kari=$kari.",[".$LB[$iii]->[0].",".$LB[$iii]->[1]."]";
         }
        }
        $kari=$kari."]},\"properties\": {".join(',', @karip)."}}";
        
        if ($tlcnt{$key}) {
          $tlcnt{$key}=$tlcnt{$key}.",\n".$kari;
        } else {
         $tlcnt{$key}=$kari;
        }
        
        @LB=([$LB_clip[$ii]->[0],$LB_clip[$ii]->[1]]);
      }
     }
     
     #最後の点の処理
     if($i == @point-1){
       push(@LB,[$point[$i]->X,$point[$i]->Y]);
       my $key=LB2XYTILE($zoom,@LB);
       my $kari="{ \"type\": \"Feature\",\"geometry\": {\"type\": \"LineString\", \"coordinates\": [";
       for (my $iii=0; $iii<@LB; $iii++) {
        if($iii==0){
          $kari=$kari."[".$LB[$iii]->[0].",".$LB[$iii]->[1]."]";
        }else{
          $kari=$kari.",[".$LB[$iii]->[0].",".$LB[$iii]->[1]."]";
        }
       }
        $kari=$kari."]},\"properties\": {".join(',', @karip)."}}";
       
       if ($tlcnt{$key}) {
          $tlcnt{$key}=$tlcnt{$key}.",\n".$kari;
       } else {
         $tlcnt{$key}=$kari;
       }
       
       @LB=();
     }
    }

}

 }
}


##############ファイル書き出し############
print "tile out..\n";
foreach my $key (keys(%tlcnt)){
 @k= split(/\//,$key);
 mkpath("./". @k[0]."/".@k[1]);
 
open(FOUT,">:utf8","./".$key.".geojson");
flock(FOUT,2);
print FOUT<<ENDJSON;
{ "type": "FeatureCollection",
"features": [
$tlcnt{$key}
]
}
ENDJSON
close(FOUT);
}





#タイル算出
use Math::Trig;
sub LB2XYTILE {
my $zoom=shift;
my @LB=@_;

my $L = 0;
my $B = 0;
my $num = @LB;
foreach my $p (@LB){
 $L = $L + $p->[0];
 $B = $B + $p->[1];
}
$L = $L / $num;
$B = $B / $num;

my $tileSize=256;
my $initialResolution = 2 * pi() / $tileSize;
my $Resolution = $initialResolution / (2**$zoom);
my $originShift = 2 * pi() / 2.0;

my $X=deg2rad($L) ;
my $Y=log(tan(pi/4 + deg2rad($B)/2));

my $tx=int(($X + $originShift)/($tileSize * $Resolution));
my $ty=int(($Y + $originShift)/($tileSize * $Resolution));

$ty = 2**$zoom - $ty -1;

return ($zoom."/".$tx."/".$ty);
}


#真球メルカトル投影変換・タイル座標
use Math::Trig;
sub LB2XY {
my $L=shift;
my $B=shift;
my $zoom=shift;

my $tileSize=256;
my $initialResolution = 2 * pi() / $tileSize;
my $Resolution = $initialResolution / (2**$zoom);
my $originShift = 2 * pi() / 2.0;

my $X=deg2rad($L) ;
my $Y=log(tan(pi/4 + deg2rad($B)/2));

#my $tx=int(($X + $originShift)/($tileSize * $Resolution));
#my $ty=int(($Y + $originShift)/($tileSize * $Resolution));
my $tx=($X + $originShift)/($tileSize * $Resolution);
my $ty=($Y + $originShift)/($tileSize * $Resolution);

$ty = 2**$zoom - $ty;

return ($tx,$ty);
}

#タイル座標緯度経度変換
use Math::Trig;
sub XY2LB {
my $tx=shift;
my $ty=shift;
my $zoom=shift;
$ty = 2**$zoom - $ty;

my $tileSize=256;
my $initialResolution = 2 * pi() / $tileSize;
my $Resolution = $initialResolution / (2**$zoom);
my $originShift = 2 * pi() / 2.0;

my $X = $tx * $tileSize * $Resolution - $originShift;
my $Y = $ty * $tileSize * $Resolution - $originShift;

my $L = ($X / $originShift) * 180.0;
my $B = ($Y / $originShift) * 180.0;
$B = 180 / pi() * (2 * atan( exp( $B * pi() / 180.0)) - pi() / 2.0);

return ($L,$B);
}


#ライン分割
use Math::Trig;
use POSIX;
use List::Util qw/ max min /;
sub CLIPLINE {
my $X1=shift;
my $Y1=shift;
my $X2=shift;
my $Y2=shift;
my $zoom=shift;
my $XMAX = ceil(max($X1,$X2));
my $XMIN = int(min($X1,$X2));
my $YMAX = ceil(max($Y1,$Y2));
my $YMIN = int(min($Y1,$Y2));
my $Xck= $XMAX-$XMIN;
my $Yck= $YMAX-$YMIN;
my @LB = ();
for (my $i=1; $i<$Xck; $i++) {
 my $X = $XMIN + $i;
 my $Y = ($Y2-$Y1)/($X2-$X1)*$X + ($X2*$Y1-$X1*$Y2)/($X2-$X1);
 push(@LB,[XY2LB($X,$Y,$zoom)]);
}
for (my $i=1; $i<$Yck; $i++) {
 my $Y = $YMIN + $i;
 my $X = ($X2-$X1)/($Y2-$Y1)*$Y + ($Y2*$X1-$Y1*$X2)/($Y2-$Y1);
 push(@LB,[XY2LB($X,$Y,$zoom)]);
}
my %count;
@LB = grep( !$count{$_->[0].$_->[1]}++, @LB ) ;
if($X1 != $X2){
 if($X2>$X1){
  @LB = sort {$a->[0] <=> $b->[0]} @LB;
 }else{
  @LB = sort {$b->[0] <=> $a->[0]} @LB;
 }
}else{
 if($Y2>$Y1){
  @LB = sort {$b->[1] <=> $a->[1]} @LB;
 }else{
  @LB = sort {$a->[1] <=> $b->[1]} @LB;
 }
}

return @LB;
}


#クリップ前判定
use Math::Trig;
use POSIX;
use List::Util qw/ max min /;
sub CLIPMAE {
my $X1=shift;
my $Y1=shift;
my $X2=shift;
my $Y2=shift;
my $XMAX = ceil(max($X1,$X2));
my $XMIN = int(min($X1,$X2));
my $YMAX = ceil(max($Y1,$Y2));
my $YMIN = int(min($Y1,$Y2));
my $Xck= $XMAX-$XMIN;
my $Yck= $YMAX-$YMIN;
my $flag = 0;

if( $Xck>1 || $Yck>1 ){$flag = 1;}

return $flag;
}
