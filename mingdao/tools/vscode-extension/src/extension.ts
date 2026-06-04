import * as vscode from 'vscode';
import { LanguageClient, LanguageClientOptions, ServerOptions, TransportKind } from 'vscode-languageclient';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext) {
    console.log('明道语言扩展已激活');

    // 启动LSP服务器
    startLanguageServer(context);

    // 注册命令
    registerCommands(context);

    // 注册格式化提供者
    registerFormatter(context);
}

function startLanguageServer(context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('mingdao');
    
    if (!config.get<boolean>('lsp.enabled', true)) {
        return;
    }

    // LSP服务器路径（需要根据实际路径调整）
    const serverPath = context.asAbsolutePath('../lsp/server.rkt');
    
    const serverOptions: ServerOptions = {
        command: 'racket',
        args: [serverPath],
        transport: TransportKind.stdio
    };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'mingdao' }],
        synchronize: {
            configurationSection: 'mingdao'
        }
    };

    client = new LanguageClient(
        'mingdaoLanguageServer',
        '明道语言服务器',
        serverOptions,
        clientOptions
    );

    client.start();
}

function registerCommands(context: vscode.ExtensionContext) {
    // 格式化文档命令
    const formatCommand = vscode.commands.registerCommand(
        'mingdao.formatDocument',
        () => {
            const editor = vscode.window.activeTextEditor;
            if (editor && editor.document.languageId === 'mingdao') {
                vscode.commands.executeCommand('editor.action.formatDocument');
            }
        }
    );

    // 启动调试器命令
    const debugCommand = vscode.commands.registerCommand(
        'mingdao.startDebugger',
        () => {
            vscode.window.showInformationMessage('调试器已启动');
            // 这里可以集成调试适配器协议
        }
    );

    // 安装包命令
    const installPackageCommand = vscode.commands.registerCommand(
        'mingdao.installPackage',
        async () => {
            const packageName = await vscode.window.showInputBox({
                prompt: '输入要安装的包名'
            });
            if (packageName) {
                vscode.window.showInformationMessage(`正在安装包: ${packageName}`);
                // 这里可以调用包管理器
            }
        }
    );

    context.subscriptions.push(formatCommand, debugCommand, installPackageCommand);
}

function registerFormatter(context: vscode.ExtensionContext) {
    const formatter = vscode.languages.registerDocumentFormattingEditProvider(
        { language: 'mingdao' },
        {
            provideDocumentFormattingEdits(document: vscode.TextDocument): vscode.TextEdit[] {
                const config = vscode.workspace.getConfiguration('mingdao.format');
                const indentSize = config.get<number>('indentSize', 4);
                const useTabs = config.get<boolean>('useTabs', false);

                const edits: vscode.TextEdit[] = [];
                const text = document.getText();
                const lines = text.split('\n');

                // 简单的格式化逻辑
                let indentLevel = 0;
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.endsWith(':') || line.includes('那么') || line.includes('否则')) {
                        indentLevel++;
                    }
                    
                    const indentStr = useTabs ? '\t'.repeat(indentLevel) : ' '.repeat(indentLevel * indentSize);
                    const formattedLine = indentStr + line;
                    
                    if (formattedLine !== lines[i]) {
                        edits.push(vscode.TextEdit.replace(
                            new vscode.Range(i, 0, i, lines[i].length),
                            formattedLine
                        ));
                    }

                    if (line.includes('跳出') || line.includes('继续') || line.includes('返回')) {
                        indentLevel = Math.max(0, indentLevel - 1);
                    }
                }

                return edits;
            }
        }
    );

    context.subscriptions.push(formatter);
}

export function deactivate(): Thenable<void> | undefined {
    if (client) {
        return client.stop();
    }
    return undefined;
}