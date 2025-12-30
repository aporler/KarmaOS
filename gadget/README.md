# Custom Gadget for KarmaOS

This directory contains a custom PC gadget with larger partitions to accommodate a full desktop environment.

## Partition sizes (vs official pc gadget):

| Partition | Official | KarmaOS Custom |
|-----------|----------|----------------|
| ubuntu-seed | 1200MB | 3000MB (2.5x) |
| ubuntu-boot | 750MB | 2000MB (2.7x) |
| ubuntu-data | varies | 8GB minimum |

This allows for:
- Full Plasma Desktop
- Multiple browsers
- Office applications
- Development tools

## Building

The gadget will be built automatically in GitHub Actions.
