import { expect, test } from 'claude-code/testing';

const report = {
  schema: 'fresh-output/v1', cwd: '/work/my-project', preview: true,
  exitCode: 0, output: '✓ Sync main\n  kept feat/wip\n⚠ build failed (continuing)',
};
const site = {
  plugin: 'fresh', component: 'ToolResult', requestId: 'fresh-output-test',
  viewport: { columns: 100, rows: 30 },
} as const;

for (const surface of ['terminal', 'desktop'] as const) {
  test(`${surface}: preserves actual output and distinguishes preview, completed, failed`, async ($, on) => {
    on('ui.render', () => ({ type: 'Text', props: {}, children: ['native fallback'] }));
    for (const [preview, exitCode, status] of [[true, 0, 'Preview'], [false, 0, 'Completed'], [false, 7, 'Failed']] as const) {
      const value = { ...report, preview, exitCode };
      const ui = await $.ui.mount({ ...site, surface, props: {
        tool_use_id: 'fresh-output-test', tool: 'Bash', isErrored: exitCode !== 0,
        output: { stdout: JSON.stringify(value), stderr: 'streamed output' },
      } });
      expect(await ui.find({ type: 'Text', text: `camp fresh · ${status} · exit ${exitCode}` })).toBeDefined();
      const code = await ui.find({ type: 'Code' });
      expect(code?.props.source).toBe(value.output);
      await ui.unmount();
    }
  });

  test(`${surface}: unrelated and malformed outputs fall through`, async ($, on) => {
    on('ui.render', () => ({ type: 'Text', props: {}, children: ['native fallback'] }));
    for (const output of ['ordinary bash output', '{}', JSON.stringify({ ...report, exitCode: -1 }),
                          JSON.stringify({ ...report, schema: 'unknown' }),
                          JSON.stringify({ ...report, output: 'x'.repeat(60001) })]) {
      const ui = await $.ui.mount({ ...site, surface, props: {
        tool_use_id: 'fresh-output-test', tool: 'Bash', output, isErrored: false,
      } });
      expect(await ui.find({ type: 'Text', text: 'native fallback' })).toBeDefined();
      await ui.unmount();
    }
  });
}

test('failed Bash text envelopes still show failure and the transcript', async ($, on) => {
  on('ui.render', () => ({ type: 'Text', props: {}, children: ['native fallback'] }));
  const value = { ...report, exitCode: 1 };
  const ui = await $.ui.mount({ ...site, surface: 'desktop', props: {
    tool_use_id: 'fresh-output-test', tool: 'Bash', isErrored: true,
    output: 'Exit code 1\nfailed command\n' + JSON.stringify(value, null, 0).replace('"schema":', '"schema": ') + '\n',
  } });
  expect(await ui.find({ type: 'Text', text: 'camp fresh · Failed · exit 1' })).toBeDefined();
  await ui.unmount();
});
