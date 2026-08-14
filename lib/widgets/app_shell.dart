import 'package:flutter/material.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/global_search_screen.dart';
import '../screens/library_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subjects_screen.dart';
import '../screens/tasks_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'v22_actions.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  static const destinations = [
    (Icons.today_rounded, 'Hoje'),
    (Icons.auto_stories_rounded, 'Matérias'),
    (Icons.task_alt_rounded, 'Atividades'),
    (Icons.analytics_rounded, 'Desempenho'),
    (Icons.calendar_month_rounded, 'Horários'),
  ];

  @override Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    const screens = [DashboardScreen(), SubjectsScreen(), TasksScreen(), AnalyticsScreen(), ScheduleScreen()];
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      return Scaffold(
        body: SafeArea(child: Row(children: [
          if (desktop) _DesktopNav(state: state),
          Expanded(child: Column(children: [
            _TopBar(desktop: desktop, state: state),
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), switchInCurve: Curves.easeOutCubic, transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: SlideTransition(position: Tween(begin: const Offset(.015, 0), end: Offset.zero).animate(animation), child: child)), child: KeyedSubtree(key: ValueKey(state.currentIndex), child: screens[state.currentIndex]))),
          ])),
        ])),
        floatingActionButton: FloatingActionButton.extended(onPressed: () => showQuickAddSheet(context, state), icon: const Icon(Icons.add_rounded), label: const Text('Adicionar')),
        bottomNavigationBar: desktop ? null : NavigationBar(selectedIndex: state.currentIndex, onDestinationSelected: state.setIndex, destinations: [for (final d in destinations) NavigationDestination(icon: Icon(d.$1), label: d.$2)]),
      );
    });
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.state}); final AppState state;
  @override Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(width: 244, padding: const EdgeInsets.fromLTRB(16, 22, 16, 18), decoration: BoxDecoration(color: dark ? const Color(0xFF0B2832) : Colors.white, border: Border(right: BorderSide(color: dark ? Colors.white.withValues(alpha: .06) : Colors.black.withValues(alpha: .06)))), child: Column(children: [
      const Row(children: [_Logo(), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Academia Flow', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text('Academic OS • 2.2', style: TextStyle(fontSize: 10))]))]),
      const SizedBox(height: 28),
      for (var i=0;i<AppShell.destinations.length;i++) Padding(padding: const EdgeInsets.only(bottom: 6), child: Material(color: state.currentIndex==i ? Theme.of(context).colorScheme.primary.withValues(alpha:.10) : Colors.transparent, borderRadius: BorderRadius.circular(14), child: InkWell(onTap: () => state.setIndex(i), borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.symmetric(horizontal:13, vertical:12), child: Row(children:[Icon(AppShell.destinations[i].$1, size:21, color:state.currentIndex==i?Theme.of(context).colorScheme.primary:null), const SizedBox(width:11), Expanded(child:Text(AppShell.destinations[i].$2, style:TextStyle(fontWeight:state.currentIndex==i?FontWeight.w900:FontWeight.w600))), if(i==2&&state.pendingCount>0) Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:AppColors.gold,borderRadius:BorderRadius.circular(20)),child:Text('${state.pendingCount}',style:const TextStyle(color:AppColors.petroleumDark,fontSize:9,fontWeight:FontWeight.w900)))]))))),
      const Divider(height: 22),
      _SecondaryNav(icon: Icons.search_rounded, label: 'Busca global', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen()))),
      _SecondaryNav(icon: Icons.menu_book_rounded, label: 'Biblioteca', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryScreen()))),
      const Spacer(),
      if (state.semester.isNotEmpty) Container(width:double.infinity,margin:const EdgeInsets.only(bottom:14),padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:AppColors.gold.withValues(alpha:.08),borderRadius:BorderRadius.circular(15),border:Border.all(color:AppColors.gold.withValues(alpha:.16))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('SEMESTRE',style:TextStyle(color:AppColors.gold,fontSize:9,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(state.semester,style:const TextStyle(fontWeight:FontWeight.w900))])),
      Row(children:[CircleAvatar(radius:18,backgroundColor:AppColors.petroleum,child:Text(_initials(state.userName),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:11))),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(state.userName,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:12)),Text(state.period.isEmpty?state.course:'${state.course} • ${state.period}',overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:9))]))]),
    ]));
  }
}

class _SecondaryNav extends StatelessWidget { const _SecondaryNav({required this.icon, required this.label, required this.onTap}); final IconData icon; final String label; final VoidCallback onTap; @override Widget build(BuildContext context) => ListTile(dense:true,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),leading:Icon(icon,size:20),title:Text(label,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),onTap:onTap); }

class _TopBar extends StatelessWidget {
  const _TopBar({required this.desktop, required this.state}); final bool desktop; final AppState state;
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(desktop?26:17,14,desktop?26:17,7), child: Row(children:[
    if(!desktop)...[const _Logo(),const SizedBox(width:9),const Text('Academia Flow',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16))] else const Spacer(), if(!desktop) const Spacer(),
    IconButton.filledTonal(tooltip:'Busca global',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const GlobalSearchScreen())),icon:const Icon(Icons.search_rounded)), const SizedBox(width:6),
    IconButton.filledTonal(tooltip:'Biblioteca',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const LibraryScreen())),icon:const Icon(Icons.menu_book_outlined)), const SizedBox(width:6),
    IconButton.filledTonal(tooltip:'Tema',onPressed:state.toggleTheme,icon:Icon(state.isDark?Icons.light_mode_rounded:Icons.dark_mode_rounded)), const SizedBox(width:6),
    IconButton.filledTonal(tooltip:'Configurações',onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const SettingsScreen())),icon:const Icon(Icons.settings_outlined)),
  ]));
}

class _Logo extends StatelessWidget { const _Logo(); @override Widget build(BuildContext context) => Container(width:41,height:41,decoration:BoxDecoration(gradient:const LinearGradient(colors:[AppColors.petroleum,Color(0xFF17697A)],begin:Alignment.topLeft,end:Alignment.bottomRight),borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.school_rounded,color:AppColors.gold,size:22)); }
String _initials(String name){final p=name.trim().split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).toList();if(p.isEmpty)return'AF';if(p.length==1)return p.first.substring(0,1).toUpperCase();return'${p.first[0]}${p.last[0]}'.toUpperCase();}
