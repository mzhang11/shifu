/**
 * Copyright [2012-2014] PayPal Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
REGISTER $path_jar;

SET pig.exec.reducers.max 999;
SET pig.exec.reducers.bytes.per.reducer 536870912;
SET mapred.map.tasks.speculative.execution true;
SET mapred.reduce.tasks.speculative.execution true;
SET mapreduce.map.speculative true;
SET mapreduce.reduce.speculative true;
SET mapred.job.queue.name $queue_name;
SET mapred.task.timeout 1200000;
SET job.name 'Shifu Statistic: $data_set';
SET io.sort.mb 500;
SET mapred.child.java.opts -Xmx1G;
SET mapred.child.ulimit 2.5G;
SET mapred.reduce.slowstart.completed.maps 0.6;

DEFINE IsDataFilterOut  ml.shifu.shifu.udf.PurifyDataUDF('$source_type', '$path_model_config', '$path_column_config');
DEFINE IsToBinningData  ml.shifu.shifu.udf.FilterBinningDataUDF('$source_type', '$path_model_config', '$path_column_config');
DEFINE GenBinningData   ml.shifu.shifu.udf.BinningDataUDF('$source_type', '$path_model_config', '$path_column_config');
DEFINE AddColumnNum     ml.shifu.shifu.udf.AddColumnNumAndFilterUDF('$source_type', '$path_model_config', '$path_column_config', 'false', 'false');

-- load and purify data
data = LOAD '$path_raw_data' USING PigStorage('$delimiter');
data = FILTER data BY IsDataFilterOut(*);

-- convert data into column based
data_cols = FOREACH data GENERATE AddColumnNum(*);
data_cols = FILTER data_cols BY $0 IS NOT NULL;
data_cols = FOREACH data_cols GENERATE FLATTEN($0);

-- Do binning
data_binning_grp = GROUP data_cols BY $0 PARALLEL $column_parallel;
binning_info = FOREACH data_binning_grp GENERATE FLATTEN(GenBinningData(*));
STORE binning_info INTO '$path_stats_binning_info' USING PigStorage('|', '-schema');
