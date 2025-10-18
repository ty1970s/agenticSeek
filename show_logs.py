#!/usr/bin/env python3
"""
AgenticSeek 日志查看器
用于查看和分析 AgenticSeek 项目的日志文件
"""

import os
import sys
import argparse
import datetime
import time
import re
from pathlib import Path
from typing import Dict, List, Optional
import threading
from collections import defaultdict

try:
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich.text import Text
    from rich.live import Live
    from rich.layout import Layout
    from rich.syntax import Syntax
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False


class LogViewer:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        self.log_dir = self.script_dir / ".logs"
        self.main_log = self.script_dir / "agenticseek.log"
        
        self.log_files = {
            "backend": self.log_dir / "backend.log",
            "browser": self.log_dir / "browser.log",
            "browser_agent": self.log_dir / "browser_agent.log",
            "code_agent": self.log_dir / "code_agent.log",
            "language": self.log_dir / "language.log",
            "memory": self.log_dir / "memory.log",
            "planner_agent": self.log_dir / "planner_agent.log",
            "provider": self.log_dir / "provider.log",
            "router": self.log_dir / "router.log",
            "tools": self.log_dir / "tools.log",
            "main": self.main_log
        }
        
        if RICH_AVAILABLE:
            self.console = Console()
        else:
            self.console = None
    
    def print_colored(self, text: str, color: str = "white") -> None:
        """打印彩色文本"""
        if self.console:
            self.console.print(text, style=color)
        else:
            print(text)
    
    def list_logs(self) -> None:
        """列出所有可用的日志文件"""
        if self.console:
            table = Table(title="AgenticSeek 日志文件")
            table.add_column("日志名称", style="cyan")
            table.add_column("文件路径", style="green")
            table.add_column("大小", style="yellow")
            table.add_column("行数", style="blue")
            table.add_column("状态", style="magenta")
            
            for log_name, log_path in self.log_files.items():
                if log_path.exists():
                    size = self.get_file_size(log_path)
                    lines = self.get_file_lines(log_path)
                    status = "✓ 存在"
                    status_style = "green"
                else:
                    size = "-"
                    lines = "-"
                    status = "✗ 不存在"
                    status_style = "red"
                
                table.add_row(
                    log_name,
                    str(log_path),
                    size,
                    str(lines) if lines != "-" else lines,
                    f"[{status_style}]{status}[/{status_style}]"
                )
            
            self.console.print(table)
        else:
            print("AgenticSeek 日志文件:")
            print("-" * 80)
            for log_name, log_path in self.log_files.items():
                if log_path.exists():
                    size = self.get_file_size(log_path)
                    lines = self.get_file_lines(log_path)
                    status = "存在"
                else:
                    size = "-"
                    lines = "-"
                    status = "不存在"
                
                print(f"  {log_name:15} | {str(log_path):40} | {size:8} | {lines:6} 行 | {status}")
    
    def get_file_size(self, file_path: Path) -> str:
        """获取文件大小"""
        try:
            size_bytes = file_path.stat().st_size
            if size_bytes < 1024:
                return f"{size_bytes}B"
            elif size_bytes < 1024 * 1024:
                return f"{size_bytes / 1024:.1f}KB"
            else:
                return f"{size_bytes / (1024 * 1024):.1f}MB"
        except:
            return "-"
    
    def get_file_lines(self, file_path: Path) -> int:
        """获取文件行数"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                return sum(1 for _ in f)
        except:
            return 0
    
    def tail_file(self, file_path: Path, lines: int = 50) -> List[str]:
        """获取文件的最后几行"""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                return f.readlines()[-lines:]
        except:
            return []
    
    def parse_log_line(self, line: str) -> Dict[str, str]:
        """解析日志行"""
        # 匹配格式: 2024-01-01 12:00:00,123 - logger_name - LEVEL - message
        pattern = r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}) - ([^-]+) - ([^-]+) - (.+)'
        match = re.match(pattern, line.strip())
        
        if match:
            return {
                'timestamp': match.group(1),
                'logger': match.group(2).strip(),
                'level': match.group(3).strip(),
                'message': match.group(4).strip()
            }
        else:
            return {
                'timestamp': '',
                'logger': '',
                'level': '',
                'message': line.strip()
            }
    
    def get_log_level_color(self, level: str) -> str:
        """根据日志级别返回颜色"""
        level = level.upper()
        colors = {
            'DEBUG': 'bright_black',
            'INFO': 'green',
            'WARNING': 'yellow',
            'ERROR': 'red',
            'CRITICAL': 'bold red'
        }
        return colors.get(level, 'white')
    
    def show_log(self, log_name: str, lines: int = 50, follow: bool = False, 
                 filter_level: Optional[str] = None) -> None:
        """显示指定日志文件"""
        if log_name not in self.log_files:
            self.print_colored(f"错误: 未知的日志名称 '{log_name}'", "red")
            return
        
        log_path = self.log_files[log_name]
        if not log_path.exists():
            self.print_colored(f"警告: 日志文件 '{log_path}' 不存在", "yellow")
            return
        
        if follow:
            self._follow_log(log_path, lines, filter_level)
        else:
            self._show_static_log(log_path, lines, filter_level, log_name)
    
    def _show_static_log(self, log_path: Path, lines: int, filter_level: Optional[str], log_name: str) -> None:
        """显示静态日志"""
        log_lines = self.tail_file(log_path, lines)
        
        if self.console:
            self.console.print(Panel(f"[bold green]{log_name} 日志[/bold green] - {log_path}"))
        else:
            print(f"=== {log_name} 日志 ({log_path}) ===")
        
        for line in log_lines:
            parsed = self.parse_log_line(line)
            
            if filter_level and parsed['level'].upper() != filter_level.upper():
                continue
            
            if self.console and parsed['level']:
                color = self.get_log_level_color(parsed['level'])
                formatted_line = (
                    f"[bright_black]{parsed['timestamp']}[/bright_black] "
                    f"[cyan]{parsed['logger']}[/cyan] "
                    f"[{color}]{parsed['level']}[/{color}] "
                    f"{parsed['message']}"
                )
                self.console.print(formatted_line)
            else:
                print(line.rstrip())
    
    def _follow_log(self, log_path: Path, lines: int, filter_level: Optional[str]) -> None:
        """实时跟踪日志文件"""
        self.print_colored(f"实时跟踪日志文件: {log_path}", "green")
        self.print_colored("按 Ctrl+C 退出", "yellow")
        
        # 首先显示最后几行
        recent_lines = self.tail_file(log_path, lines)
        for line in recent_lines:
            self._print_log_line(line, filter_level)
        
        # 开始跟踪新行
        try:
            with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
                # 移动到文件末尾
                f.seek(0, 2)
                
                while True:
                    line = f.readline()
                    if line:
                        self._print_log_line(line, filter_level)
                    else:
                        time.sleep(0.1)
        except KeyboardInterrupt:
            self.print_colored("\n日志跟踪已停止", "yellow")
    
    def _print_log_line(self, line: str, filter_level: Optional[str]) -> None:
        """打印单行日志"""
        parsed = self.parse_log_line(line)
        
        if filter_level and parsed['level'].upper() != filter_level.upper():
            return
        
        if self.console and parsed['level']:
            color = self.get_log_level_color(parsed['level'])
            formatted_line = (
                f"[bright_black]{parsed['timestamp']}[/bright_black] "
                f"[cyan]{parsed['logger']}[/cyan] "
                f"[{color}]{parsed['level']}[/{color}] "
                f"{parsed['message']}"
            )
            self.console.print(formatted_line)
        else:
            print(line.rstrip())
    
    def show_all_logs(self, lines: int = 50, follow: bool = False) -> None:
        """显示所有日志文件"""
        if follow:
            self._follow_all_logs(lines)
        else:
            for log_name, log_path in self.log_files.items():
                if log_path.exists():
                    self._show_static_log(log_path, lines, None, log_name)
                    print()
    
    def _follow_all_logs(self, lines: int) -> None:
        """实时跟踪所有日志文件"""
        self.print_colored("实时跟踪所有日志文件...", "green")
        self.print_colored("按 Ctrl+C 退出", "yellow")
        
        # 创建一个线程来跟踪每个日志文件
        threads = []
        
        try:
            for log_name, log_path in self.log_files.items():
                if log_path.exists():
                    thread = threading.Thread(
                        target=self._follow_single_in_thread,
                        args=(log_path, log_name, lines)
                    )
                    thread.daemon = True
                    thread.start()
                    threads.append(thread)
            
            # 等待所有线程
            for thread in threads:
                thread.join()
                
        except KeyboardInterrupt:
            self.print_colored("\n所有日志跟踪已停止", "yellow")
    
    def _follow_single_in_thread(self, log_path: Path, log_name: str, lines: int) -> None:
        """在线程中跟踪单个日志文件"""
        try:
            with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
                f.seek(0, 2)  # 移动到文件末尾
                
                while True:
                    line = f.readline()
                    if line:
                        # 添加日志来源标识
                        if self.console:
                            self.console.print(f"[bold magenta][{log_name}][/bold magenta] {line.rstrip()}")
                        else:
                            print(f"[{log_name}] {line.rstrip()}")
                    else:
                        time.sleep(0.1)
        except:
            pass
    
    def search_logs(self, pattern: str, log_names: Optional[List[str]] = None) -> None:
        """在日志中搜索模式"""
        if log_names is None:
            log_names = list(self.log_files.keys())
        
        self.print_colored(f"搜索模式: {pattern}", "green")
        print()
        
        for log_name in log_names:
            if log_name not in self.log_files:
                continue
                
            log_path = self.log_files[log_name]
            if not log_path.exists():
                continue
            
            matches = []
            try:
                with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
                    for line_num, line in enumerate(f, 1):
                        if re.search(pattern, line, re.IGNORECASE):
                            matches.append((line_num, line.strip()))
            except:
                continue
            
            if matches:
                self.print_colored(f"=== {log_name} ({len(matches)} 个匹配) ===", "cyan")
                for line_num, line in matches:
                    if self.console:
                        self.console.print(f"[yellow]{line_num:4d}[/yellow]: {line}")
                    else:
                        print(f"{line_num:4d}: {line}")
                print()


def main():
    parser = argparse.ArgumentParser(
        description="AgenticSeek 日志查看器",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  %(prog)s --list                    # 列出所有日志文件
  %(prog)s backend                   # 显示后端日志
  %(prog)s --follow backend          # 实时跟踪后端日志
  %(prog)s --all --lines 100         # 显示所有日志的最后100行
  %(prog)s --search "error"          # 搜索包含 "error" 的日志行
  %(prog)s --level ERROR backend     # 只显示ERROR级别的日志
        """
    )
    
    parser.add_argument('log_name', nargs='?', help='要显示的日志名称')
    parser.add_argument('-l', '--list', action='store_true', help='列出所有可用的日志文件')
    parser.add_argument('-a', '--all', action='store_true', help='显示所有日志文件')
    parser.add_argument('-f', '--follow', action='store_true', help='实时跟踪日志文件')
    parser.add_argument('-n', '--lines', type=int, default=50, help='显示的行数 (默认: 50)')
    parser.add_argument('--level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], 
                       help='过滤日志级别')
    parser.add_argument('-s', '--search', help='搜索日志中的模式')
    parser.add_argument('--clear', action='store_true', help='清空屏幕')
    
    args = parser.parse_args()
    
    if args.clear:
        os.system('clear' if os.name == 'posix' else 'cls')
    
    viewer = LogViewer()
    
    if not RICH_AVAILABLE:
        print("提示: 安装 'rich' 库可以获得更好的显示效果: pip install rich")
        print()
    
    if args.list:
        viewer.list_logs()
    elif args.search:
        log_names = [args.log_name] if args.log_name else None
        viewer.search_logs(args.search, log_names)
    elif args.all:
        viewer.show_all_logs(args.lines, args.follow)
    elif args.log_name:
        viewer.show_log(args.log_name, args.lines, args.follow, args.level)
    else:
        viewer.show_all_logs(args.lines, args.follow)


if __name__ == "__main__":
    main()
