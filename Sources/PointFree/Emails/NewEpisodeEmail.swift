import Css
import Either
import Foundation
import Html
import HtmlCssSupport
import HttpPipeline
import HttpPipelineHtmlSupport
import Optics
import Prelude
import Styleguide

let newEpisodeEmail = simpleEmailLayout(newEpisodeEmailContent)
  .contramap { episode, subscriberAnnouncement, nonSubscriberAnnouncement, user in
    SimpleEmailLayoutData(
      user: user,
      newsletter: .newEpisode,
      title: "New Point-Free Episode: \(episode.title)",
      preheader: episode.blurb,
      template: .default,
      data: (
        episode,
        user.subscriptionId != nil
          ? subscriberAnnouncement
          : nonSubscriberAnnouncement,
        user.subscriptionId != nil
      )
    )
}

let newEpisodeEmailContent = View<(Episode, String?, isSubscriber: Bool)> { ep, announcement, isSubscriber in
  emailTable([style(contentTableStyles)], [
    tr([
      td([valign(.top)], [
        div([`class`([Class.padding([.mobile: [.all: 0], .desktop: [.all: 2]])])],

            announcementView.view(announcement) <> [

              a([href(url(to: .episode(.left(ep.slug))))], [
                h3([`class`([Class.pf.type.responsiveTitle3])], [text("#\(ep.sequence): \(ep.title)")]),
                ]),
              p([text(ep.blurb)]),
              p([`class`([Class.padding([.mobile: [.topBottom: 2]])])], [
                a([href(url(to: .episode(.left(ep.slug))))], [
                  img(src: ep.image, alt: "", [style(maxWidth(.pct(100)))])
                  ])
                ])
              ]
              <> nonSubscriberCtaView.view((ep, isSubscriber))
              <> subscriberCtaView.view((ep, isSubscriber))
              <> hostSignOffView.view(unit))
        ])
      ])
    ])
}

private let announcementView = View<String?> { announcement -> [Node] in
  guard let announcement = announcement, !announcement.isEmpty else { return [] }

  return [
    blockquote(
      [
        `class`(
          [
            Class.padding([.mobile: [.all: 2]]),
            Class.margin([.mobile: [.leftRight: 0, .topBottom: 3]]),
            Class.pf.colors.bg.blue900,
            Class.type.italic
          ]
        )
      ],
      [
        h5([`class`([Class.pf.type.responsiveTitle5])], ["Announcements"]),
        markdownBlock(announcement)
      ]
    )
  ]
}

private let nonSubscriberCtaView = View<(Episode, isSubscriber: Bool)> { ep, isSubscriber -> [Node] in
  guard !isSubscriber else { return [] }

  let blurb = ep.subscriberOnly
    ? "This episode is for subscribers only. To access it, and all past and future episodes, become a subscriber today!"
    : "This episode is free for everyone, made possible by our subscribers. Consider becoming a subscriber today!"

  let watchText = ep.subscriberOnly
    ? "Watch preview"
    : "Watch"

  return [
    p([text(blurb)]),
    p([`class`([Class.padding([.mobile: [.topBottom: 2]])])], [
      a([href(url(to: .pricing(nil, expand: nil))), `class`([Class.pf.components.button(color: .purple)])],
        ["Subscribe to Point-Free!"]
      ),
      a(
        [
          href(url(to: .episode(.left(ep.slug)))),
            `class`([Class.pf.components.button(color: .black, style: .underline), Class.display.inlineBlock])
        ],
        [text(watchText)]
      )
      ])
  ]
}

private let subscriberCtaView = View<(Episode, isSubscriber: Bool)> { (ep, isSubscriber) -> [Node] in
  guard isSubscriber else { return [] }

  return [
    p([text("This episode is \(ep.length / 60) minutes long.")]),
    p([`class`([Class.padding([.mobile: [.topBottom: 2]])])], [
      a([href(url(to: .episode(.left(ep.slug)))), `class`([Class.pf.components.button(color: .purple)])],
        ["Watch now!"])
      ])
  ]
}

let newEpisodeEmailAdminReportEmail = simpleEmailLayout(newEpisodeEmailAdminReportEmailContent)
  .contramap { erroredUsers, totalAttempted in
    SimpleEmailLayoutData(
      user: nil,
      newsletter: nil,
      title: "New episode email finished sending!",
      preheader: "\(totalAttempted) attempted emails, \(erroredUsers.count) errors",
      template: .default,
      data: (erroredUsers, totalAttempted)
    )
}

let newEpisodeEmailAdminReportEmailContent = View<([Database.User], Int)> { erroredUsers, totalAttempted in
  emailTable([style(contentTableStyles)], [
    tr([
      td([valign(.top)], [
        div([`class`([Class.padding([.mobile: [.all: 1], .desktop: [.all: 2]])])], [
          h3([`class`([Class.pf.type.responsiveTitle3])], ["New episode email report"]),
          p([
            "A total of ",
            strong([text("\(totalAttempted)")]),
            " emails were attempted to be sent, and of those, ",
            strong([text("\(erroredUsers.count)")]),
            " emails failed to send. Here is the list of users that we ",
            "had trouble sending to their emails:"
            ]),

          ul(erroredUsers.map { user in
            li([text(user.name.map { "\($0) (\(user.email)" } ?? user.email.rawValue)])
          })
          ])
        ])
      ])
    ])
}
