{% if not (theme.duoshuo and theme.duoshuo.shortname)
    and not theme.duoshuo_shortname
    and not theme.disqus_shortname
    and not theme.hypercomments_id
    and not theme.gentie_productKey %}

    {% if theme.isso_ip %}
      {% set ip = theme.isso_ip %}
    {% endif %}

   {% if page.comments %}
        <!-- UY BEGIN -->
        <script 
        data-isso="{{ip}}" 
        data-isso-require-author="true"
        data-isso-require-email="true"
        data-isso-vote="false"
        data-isso-avatar="true"
        src="/js/isso.embed.min.js"></script>
        <!-- UY END -->
    {% endif %}
{% endif %}
