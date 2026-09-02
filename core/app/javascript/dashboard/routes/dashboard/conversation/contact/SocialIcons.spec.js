import { mount } from '@vue/test-utils';

import SocialIcons from './SocialIcons.vue';

describe('SocialIcons', () => {
  it('renders accessible links with valid icon classes', () => {
    const wrapper = mount(SocialIcons, {
      props: {
        socialProfiles: {
          github: 'octocat',
          instagram: 'openai',
        },
      },
    });
    const links = wrapper.findAll('a');

    expect(links).toHaveLength(2);
    expect(links[0].attributes()).toMatchObject({
      href: 'https://github.com/octocat',
      target: '_blank',
      'aria-label': 'GitHub: octocat',
    });
    expect(links[0].get('span').classes()).toContain('i-lucide-github');
    expect(links[1].get('span').classes()).toContain('i-woot-instagram');
  });

  it('does not render an empty social group', () => {
    const wrapper = mount(SocialIcons);

    expect(wrapper.find('div').exists()).toBe(false);
  });
});
