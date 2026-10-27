import 'package:flutter/material.dart';
import '../services/api.dart';

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({super.key, required this.api, required this.section,required this.date,required this.foods,required this.onChanged});
  final Api api;
  final int section;
  final String date;
  final List<dynamic> foods;
  final Future<void> Function() onChanged;
  @override State<AdvancedScreen> createState()=>_AdvancedScreenState();
}

class _AdvancedScreenState extends State<AdvancedScreen> {
  bool waiting=false;
  String? error;
  Map<String,dynamic> result={};
  final fields=<String,TextEditingController>{};
  final search=TextEditingController();
  final duration=ValueNotifier<int>(7);
  final amount=TextEditingController(text:'250');
  List<dynamic> favoriteIds=[];
  String get end=>widget.date;
  String start(int days) => DateTime.parse(end).subtract(Duration(days:days-1)).toIso8601String().substring(0,10);
  @override void initState(){super.initState();load();}
  @override void didUpdateWidget(covariant AdvancedScreen old){super.didUpdateWidget(old);if(old.section!=widget.section || old.date!=widget.date){for(final c in fields.values){c.dispose();}fields.clear();result={};favoriteIds=[];load();}}
  @override void dispose(){for(final f in fields.values){f.dispose();}search.dispose();duration.dispose();amount.dispose();super.dispose();}
  Future<void> load() async {
    setState(() {waiting=true;error=null;});
    try {
      dynamic value;
      if(widget.section==0) value=await widget.api.rangeReport(start(duration.value),end);
      if(widget.section==1) value=await widget.api.goals();
      if(widget.section==2) value=await widget.api.water(end);
      if(widget.section==3) value=await widget.api.profile();
      if(widget.section==4) value=await widget.api.favorites();
      if(!mounted)return;
      setState((){ if(value is Map) result=Map<String,dynamic>.from(value);if(value is List) favoriteIds=value; });
    }catch(e){if(mounted)setState(()=>error='$e');}
    finally{if(mounted)setState(()=>waiting=false);}
  }
  Future<void> run(Future<void> Function() action) async {
    try {setState(()=>waiting=true);await action();if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Saved successfully')));await load();await widget.onChanged();}
    catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Error: $e')));}
    finally{if(mounted)setState(()=>waiting=false);}
  }
  Widget input(String key,String label,{bool decimal=false}) {
    if(!fields.containsKey(key)){fields[key]=TextEditingController(text:result[key]?.toString()??'');}
    return Padding(padding:const EdgeInsets.only(bottom:12), child:TextField(controller:fields[key],keyboardType:TextInputType.numberWithOptions(decimal:decimal),decoration:InputDecoration(labelText:label)));
  }
  Widget card(Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:child));
  Widget report(){
    final rows=(result['days'] as List?)??[];
    final totals=(result['totals'] as Map?)??{};
    final averages=(result['averages'] as Map?)??{};
    final maxCal=rows.fold<double>(1,(v,r)=>((r['calories'] as num).toDouble()>v)?(r['calories'] as num).toDouble():v);
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SegmentedButton<int>(segments:const [ButtonSegment(value:7,label:Text('7 days')),ButtonSegment(value:30,label:Text('30 days'))],selected:{duration.value},onSelectionChanged:(v){duration.value=v.first;load();}),
      const SizedBox(height:16),Text('Total calories: ${totals['calories']??0} kcal',style:Theme.of(context).textTheme.titleMedium),
      Text('Average calories/day: ${averages['calories']??0} kcal'),
      Text('Protein ${totals['protein']??0}g   Carbs ${totals['carbs']??0}g   Fat ${totals['fat']??0}g'),
      const SizedBox(height:16),const Text('Daily Calories'),
      ...rows.map((r)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[
        SizedBox(width:88,child:Text('${r['date']}'.substring(5),style:const TextStyle(fontSize:12))),
        Expanded(child:LinearProgressIndicator(value:((r['calories'] as num).toDouble()/maxCal).clamp(0.0,1.0),minHeight:12,borderRadius:BorderRadius.circular(4))),
        SizedBox(width:65,child:Text(' ${r['calories']}',textAlign:TextAlign.right,style:const TextStyle(fontSize:12))),
      ]))),
      const SizedBox(height:12),const Text('PDF report is available from the authenticated backend endpoint /reports/pdf. Use Swagger or an authenticated API client to download it.'),
    ]));
  }
  Widget goals(){
    final keys=['calories','protein','carbs','fat','water_ml'];
    for(final k in keys){fields.putIfAbsent(k,()=>TextEditingController(text:'${result[k]??0}'));}
    return card(Column(children:[
      input('calories','Calories (kcal)'), input('protein','Protein (g)'),input('carbs','Carbs (g)'),input('fat','Fat (g)'),input('water_ml','Water goal (ml)'),
      FilledButton(onPressed:waiting?null:()=>run(()=>widget.api.saveGoals({for(final k in keys)k:int.tryParse(fields[k]!.text)??0})),child:const Text('Save Goals')),
    ]));
  }
  Widget water(){
    final logs=(result['logs'] as List?)??[];
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Water consumed on $end: ${result['total_ml']??0} ml',style:Theme.of(context).textTheme.titleMedium),
      TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Water (ml)')),
      const SizedBox(height:12),FilledButton.icon(onPressed:waiting?null:()=>run(()=>widget.api.addWater(end,int.tryParse(amount.text)??250)),icon:const Icon(Icons.add),label:const Text('Add Water')),
      ...logs.map((w)=>ListTile(title:Text('${w['amount_ml']} ml'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>run(()=>widget.api.deleteWater(w['id'] as int))))),
    ]));
  }
  Widget profile(){
    for(final k in ['age','height_cm','weight_kg']){fields.putIfAbsent(k,()=>TextEditingController(text:'${result[k]??''}'));}
    return card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${result['name']??''}',style:Theme.of(context).textTheme.titleMedium),Text('${result['email']??''}'),
      const SizedBox(height:12),input('age','Age'),input('height_cm','Height (cm)',decimal:true),input('weight_kg','Weight (kg)',decimal:true),
      FilledButton(onPressed:waiting?null:()=>run(()=>widget.api.saveProfile({
        'age':int.tryParse(fields['age']!.text),'height_cm':double.tryParse(fields['height_cm']!.text),'weight_kg':double.tryParse(fields['weight_kg']!.text),
      })),child:const Text('Save Profile')),
      const SizedBox(height:16),const Text('Settings: You can change nutrition goals from the Goals page. Account data is stored in the PostgreSQL backend database.'),
    ]));
  }
  Widget favorites(){
    final q=search.text.toLowerCase();
    final list=widget.foods.where((f)=>'${f['name']}'.toLowerCase().contains(q)).toList();
    return card(Column(children:[
      TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(labelText:'Search foods',prefixIcon:Icon(Icons.search))),
      ...list.map((f){final id=f['id'] as int;final active=favoriteIds.contains(id);return ListTile(title:Text('${f['name']}'),subtitle:Text('${f['calories']} kcal / 100g'),trailing:IconButton(icon:Icon(active?Icons.favorite:Icons.favorite_border,color:active?Colors.red:null),onPressed:()=>run(()=>active?widget.api.unfavorite(id):widget.api.favorite(id))));}),
    ]));
  }
  @override Widget build(BuildContext context){
    if(waiting && result.isEmpty && favoriteIds.isEmpty)return const Center(child:CircularProgressIndicator());
    if(error!=null)return Column(children:[Text('Error: $error'),TextButton(onPressed:load,child:const Text('Retry'))]);
    if(widget.section==0)return report();
    if(widget.section==1)return goals();
    if(widget.section==2)return water();
    if(widget.section==3)return profile();
    return favorites();
  }
}
