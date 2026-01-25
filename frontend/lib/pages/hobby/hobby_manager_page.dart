import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../constants/app_constant.dart';
import '../../utils/http_util.dart';

class HobbyManagerPage extends StatefulWidget {
  const HobbyManagerPage({super.key});

  @override
  State<HobbyManagerPage> createState() => _HobbyManagerPageState();
}

class _HobbyManagerPageState extends State<HobbyManagerPage> {
  final HttpUtil _http = HttpUtil();
  final TextEditingController _hobbyController = TextEditingController();
  List<String> _userHobbyList = [];
  static const int _maxHobbyCount = 10;

  final List<String> _presetHobby = [
    "篮球", "阅读", "编程", "跑步", "听歌",
    "摄影", "旅行", "美食", "健身", "画画",
    "书法", "下棋", "游泳", "爬山", "追剧"
  ];

  @override
  void initState() {
    super.initState();
    _loadUserHobby();
  }

  // ✅ 修复：加载兴趣列表 - 加异常捕获，数据为空时赋值空数组
  Future<void> _loadUserHobby() async {
    try {
      var res = await _http.get(AppConstant.api_user_info);
      if (res["code"] == 200) {
        setState(() {
          _userHobbyList = List<String>.from(res["data"]["hobby_list"] ?? []);
        });
      }
    } catch (e) {
      setState(() {_userHobbyList = [];});
      debugPrint("加载兴趣失败: $e");
    }
  }

  void _addCustomHobby() {
    String hobby = _hobbyController.text.trim();
    if (hobby.isEmpty) {EasyLoading.showToast("请输入兴趣");return;}
    if (_userHobbyList.length >= _maxHobbyCount) {EasyLoading.showToast("最多添加10个兴趣");return;}
    if (_userHobbyList.contains(hobby)) {EasyLoading.showToast("该兴趣已添加");return;}
    setState(() {_userHobbyList.add(hobby);_hobbyController.clear();});
  }

  void _selectPresetHobby(String hobby) {
    if (_userHobbyList.length >= _maxHobbyCount) {EasyLoading.showToast("最多添加10个兴趣");return;}
    if (!_userHobbyList.contains(hobby)) {setState(() => _userHobbyList.add(hobby));}
    else {EasyLoading.showToast("该兴趣已添加");}
  }

  void _deleteHobby(int index) {
    setState(() => _userHobbyList.removeAt(index));
  }

  // ✅ 修复：拖拽排序逻辑 - 边界值判断，无错乱
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final String hobby = _userHobbyList.removeAt(oldIndex);
      _userHobbyList.insert(newIndex, hobby);
    });
  }

  // ✅ 修复：保存兴趣逻辑 - 接口提交正确、弹窗正常关闭、返回时触发刷新
  Future<void> _saveHobby() async {
    if (_userHobbyList.isEmpty) {EasyLoading.showToast("请至少添加一个兴趣");return;}
    EasyLoading.show(status: "保存中...");
    try {
      var res = await _http.post(AppConstant.api_save_hobby, data: {"hobby_list": _userHobbyList});
      EasyLoading.dismiss();
      if (res["code"] == 200) {
        EasyLoading.showSuccess("保存成功！");
        // 返回上一页 + 通知上一页刷新数据
        Navigator.pop(context, true);
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError("保存失败，请重试");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("兴趣列表管理",style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,elevation:0,backgroundColor:Colors.white,foregroundColor:Colors.black87,
        actions: [TextButton(onPressed: _saveHobby, child:  Text("保存",style: TextStyle(color: Colors.blue.shade600,fontSize:16)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius:4)]
            ),
            child: Row(children: [
              Expanded(child: TextField(controller: _hobbyController, decoration:  InputDecoration(hintText: "输入兴趣并添加",border: InputBorder.none,hintStyle: TextStyle(color: Colors.grey.shade400)))),
              ElevatedButton(onPressed: _addCustomHobby, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600,shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("添加")),
            ],),
          ),
          const SizedBox(height:25),
          const Text("✨ 推荐兴趣（点击选择）",style: TextStyle(fontSize:16, fontWeight: FontWeight.w500)),
          const SizedBox(height:15),
          Wrap(spacing:10,runSpacing:10,children: _presetHobby.map((hobby) {
            bool isSelected = _userHobbyList.contains(hobby);
            return InkWell(
              onTap: () => _selectPresetHobby(hobby),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal:12,vertical:8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade100 : Colors.white,
                  border: Border.all(color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(20)
                ),
                child: Text(hobby,style: TextStyle(color: isSelected ? Colors.blue.shade600 : Colors.black87)),
              ),
            );
          }).toList()),
          const SizedBox(height:30),
          Text("✅ 我的兴趣 (${_userHobbyList.length}/$_maxHobbyCount)",style: TextStyle(fontSize:16, fontWeight: FontWeight.w500)),
          const SizedBox(height:15),
          _userHobbyList.isEmpty
          ? const Text("暂无兴趣，点击添加或选择推荐兴趣", style: TextStyle(color: Colors.grey))
          : Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius:4)]),
              child: ReorderableListView.builder(
                shrinkWrap: true,physics: const NeverScrollableScrollPhysics(),
                onReorder: _onReorder,itemCount: _userHobbyList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    key: Key(index.toString()),title: Text(_userHobbyList[index]),
                    trailing: IconButton(icon:  Icon(Icons.delete_outline, color: Colors.grey.shade500), onPressed: () => _deleteHobby(index)),
                    leading:  Icon(Icons.drag_indicator, color: Colors.grey.shade400),
                  );
                },
              ),
            )
        ],),
      ),
    );
  }
}