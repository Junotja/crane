#!/bin/bash

# simple script to run against running MongoDB/TokuMX server localhost:(default port)

# enable passing different config files

if [ ! $1 ];
then
    FILE="config.bash"
else
    FILE=$1
fi

if [ -f $FILE ];
then
   echo "Loading config from $FILE....."
   source $FILE
else
   echo "Unable to read config $FILE"
   exit 1
fi


# Heming cleanup work.
PORT=7000
IP=127.0.0.1

cd $MSMR_ROOT/apps/mongodb/sysbench-mongodb
#rm -rf db-dir
mkdir -p db-dir
killall -9 mongo mongod

echo "Starting mongodb server..."
$MSMR_ROOT/apps/mongodb/install/bin/mongod --port $PORT --dbpath=$PWD/db-dir --quiet &> mongodb.log &
sleep 15;

echo "Preparing for database sbtest..."
$MSMR_ROOT/apps/mongodb/install/bin/mongo --port $PORT --host $IP < cleanup.js
sleep 1;
killall -9 mongo mongod
#exit 0;

echo "Restarting mongodb server..."
L2D_PRELOAD=$XTERN_ROOT/dync_hook/interpose.so \
$MSMR_ROOT/apps/mongodb/install/bin/mongod --port $PORT --dbpath=$PWD/db-dir --quiet &> mongodb.log &
sleep 15;



echo "Running sysbench-mongodb benchmark..."
export CLASSPATH=$MSMR_ROOT/apps/mongodb/mongo-java-driver-2.13.0.jar:$CLASSPATH
javac -cp $CLASSPATH:$PWD/src src/jmongosysbenchload.java
javac -cp $CLASSPATH:$PWD/src src/jmongosysbenchexecute.java


# load the data

if [[ $DOLOAD = "yes" ]]; then
    echo Do load at $( date )
    export LOG_NAME=mongoSysbenchLoad-${NUM_COLLECTIONS}-${NUM_DOCUMENTS_PER_COLLECTION}-${NUM_LOADER_THREADS}.txt
    export BENCHMARK_TSV=${LOG_NAME}.tsv
 
    rm -f $LOG_NAME
    rm -f $BENCHMARK_TSV

    T="$(date +%s)"
    java -cp $CLASSPATH:$PWD/src jmongosysbenchload $NUM_COLLECTIONS $DB_NAME $NUM_LOADER_THREADS $NUM_DOCUMENTS_PER_COLLECTION $NUM_DOCUMENTS_PER_INSERT $NUM_INSERTS_PER_FEEDBACK $NUM_SECONDS_PER_FEEDBACK $BENCHMARK_TSV $MONGO_COMPRESSION $MONGO_BASEMENT $WRITE_CONCERN $MONGO_SERVER $MONGO_PORT $USERNAME $PASSWORD
    echo "" | tee -a $LOG_NAME
    T="$(($(date +%s)-T))"
    printf "`date` | sysbench loader duration = %02d:%02d:%02d:%02d\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))" | tee -a $LOG_NAME
fi


# execute the benchmark

if [[ $DOQUERY = "yes" ]]; then
    echo Do query at $( date )
    export LOG_NAME=mongoSysbenchExecute-${NUM_COLLECTIONS}-${NUM_DOCUMENTS_PER_COLLECTION}-${NUM_WRITER_THREADS}.txt
    export BENCHMARK_TSV=${LOG_NAME}.tsv
 
    rm -f $LOG_NAME
    rm -f $BENCHMARK_TSV

# $SYSBENCH_INSERTS  $SEED 

    T="$(date +%s)"
    java -cp $CLASSPATH:$PWD/src jmongosysbenchexecute $NUM_COLLECTIONS $DB_NAME $NUM_WRITER_THREADS $NUM_DOCUMENTS_PER_COLLECTION $NUM_SECONDS_PER_FEEDBACK $BENCHMARK_TSV $SYSBENCH_AUTO_COMMIT $RUN_TIME_SECONDS $SYSBENCH_RANGE_SIZE $SYSBENCH_POINT_SELECTS $SYSBENCH_SIMPLE_RANGES $SYSBENCH_SUM_RANGES $SYSBENCH_ORDER_RANGES $SYSBENCH_DISTINCT_RANGES $SYSBENCH_INDEX_UPDATES $SYSBENCH_NON_INDEX_UPDATES $WRITE_CONCERN $MAX_TPS $MONGO_SERVER $MONGO_PORT $USERNAME $PASSWORD | tee -a $LOG_NAME
    echo "" | tee -a $LOG_NAME
    T="$(($(date +%s)-T))"
    printf "`date` | sysbench benchmark duration = %02d:%02d:%02d:%02d\n" "$((T/86400))" "$((T/3600%24))" "$((T/60%60))" "$((T%60))" | tee -a $LOG_NAME
fi

