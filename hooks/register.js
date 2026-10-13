// Render only Fresh's versioned capture reports. This mod never runs a command,
// reads a file, changes permissions, or changes what the model receives.
function reportFrom(output) {
  const text = typeof output === 'string' ? output : output?.stdout;
  if (typeof text !== 'string' || text.length > 200000) return null;
  try {
    // Failed Bash calls can include an exit-code prefix and stderr around stdout.
    const line = text.trim().split('\n').findLast(line => line.startsWith('{"schema": "fresh-output/v1"'));
    const report = JSON.parse(line || text.trim());
    if (report.schema !== 'fresh-output/v1' || typeof report.output !== 'string' ||
        report.output.length > 60000 || typeof report.cwd !== 'string' ||
        typeof report.preview !== 'boolean' || !Number.isInteger(report.exitCode) ||
        report.exitCode < 0 || report.exitCode > 255) return null;
    return report;
  } catch { return null; }
}

export function register(on) {
  on('ui.render', { component: 'ToolResult' }, async ($, e, next) => {
    if (e.props.tool !== 'Bash') return next(e);
    const report = reportFrom(e.props.output);
    if (!report) return next(e);
    const { Box, Text, Code } = $.ui.resolve(e);
    const failed = report.exitCode !== 0 || e.props.isErrored;
    const status = failed ? 'Failed' : report.preview ? 'Preview' : 'Completed';
    const color = failed ? '#ff8b8b' : report.preview ? '#f6cf83' : '#9ed99a';
    return Box({ flexDirection: 'column', borderStyle: 'round', padding: 1, children: [
      Text({ bold: true, color, children: ['camp fresh · ' + status + ' · exit ' + report.exitCode] }),
      Text({ dimColor: true, children: [report.cwd] }),
      Code({ source: report.output, language: 'text', wrap: 'wrap' }),
    ] });
  });
}
