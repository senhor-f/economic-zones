import { defineConfig } from 'vitepress';
import { withMermaid } from 'vitepress-plugin-mermaid';

export default withMermaid(
  defineConfig({
    title: 'Economic Zones Protocol',
    description: 'Sovereign On-Chain Economic Zones with Unbreachable Floor Price, AI Agent Micropayments (x402), SaaS Subscriptions, and Yield-Backed Treasury Bóvedas.',
    srcDir: '.',
    outDir: '.vitepress/dist',
    cleanUrls: true,
    ignoreDeadLinks: true,
    themeConfig: {
      nav: [
        { text: 'Home', link: '/' },
        { text: 'Architecture', link: '/architecture/' },
        { text: 'Commerce Matrix', link: '/commerce/1click-checkout' },
        { text: 'Governance & veHNY', link: '/governance/futarchy-conviction' },
        { text: 'Cross-Chain & Blobs', link: '/architecture/cross-chain-blobs' },
        { text: 'TypeScript SDK', link: '/sdk/typescript' },
        { text: 'Deployments', link: '/operations/deployments' }
      ],
      sidebar: [
        {
          text: 'Introduction',
          items: [
            { text: 'Overview & Vision', link: '/' },
            { text: 'Core Economic Invariants', link: '/architecture/bonding-curve' },
            { text: 'Immutable Versioning', link: '/contracts/versioning' }
          ]
        },
        {
          text: 'Core Architecture',
          items: [
            { text: 'Hub-and-Spoke (L1 ↔ L2)', link: '/architecture/' },
            { text: 'Augmented Bonding Curve', link: '/architecture/bonding-curve' },
            { text: 'Treasury Vaults & Yield Dripping', link: '/architecture/rebalancing' },
            { text: 'EIP-4844 Blobs & xERC20', link: '/architecture/cross-chain-blobs' }
          ]
        },
        {
          text: 'Commercial Product Matrix',
          items: [
            { text: '1-Click Checkout & Cashback', link: '/commerce/1click-checkout' },
            { text: 'On-Chain SaaS Subscriptions', link: '/commerce/subscriptions' },
            { text: 'Revenue Splits & Auto-Staking', link: '/commerce/revenue-splits' },
            { text: 'Continuous Payroll Streaming', link: '/commerce/payroll-streaming' },
            { text: 'AI Agent Micropayments (x402)', link: '/commerce/ai-agent-micropayments' }
          ]
        },
        {
          text: 'Governance & Sovereign Fiscality',
          items: [
            { text: 'Milestone Futarchy & Conviction', link: '/governance/futarchy-conviction' },
            { text: 'veHNY Floor-Locked Savings', link: '/governance/futarchy-conviction#vehny-floor-locked-savings' },
            { text: 'Custom Tariffs & Clearing House', link: '/governance/futarchy-conviction#custom-tariffs-multi-zone-clearing' }
          ]
        },
        {
          text: 'Developer Tooling & SDK',
          items: [
            { text: '@economic-zone/checkout SDK', link: '/sdk/typescript' },
            { text: 'Deployment & Operations', link: '/operations/deployments' }
          ]
        }
      ],
      socialLinks: [
        { icon: 'github', link: 'https://github.com' }
      ],
      search: {
        provider: 'local'
      }
    },
    mermaid: {
      theme: 'base',
      themeVariables: {
        primaryColor: '#eab308',
        primaryTextColor: '#000',
        primaryBorderColor: '#ca8a04',
        lineColor: '#a1a1aa',
        secondaryColor: '#3b82f6',
        tertiaryColor: '#18181b'
      }
    }
  })
);
