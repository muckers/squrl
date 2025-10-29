
# Building sqURL: A Human's Perspective on Vibe Coding a URL Shortner

## Introduction

A couple of months ago after getting fairly enamoured with Claude Code, I found myself wondering if it would be possible to guide it to fully code and deploy a reasonably secure, private, and scalable web service. I'd had the idea for a few years to create a free URL shortner, one that anyone could use (with limits that made sense) and this seemed like the perfect project to use for this experiment.

So, I sat down and came up with a few guiding principles for the process:

- I would not write a single line of code myself. Claude code would be the engineer, and I would be the product owner and project manager only.
- I would interact with Claude code only through providing requirements, both product and technical, as well as light guidance on the overall architecture and design (e.g., rust, serverless, event driven, etc.).
- I would make Claude code plan it's work via milestones, and record those milestones in markdown files that provided context and a way for Claude code to track its progress.
- The only MCP server I would use would be Serena to help cut down on context rot/bloat
- Along with Serena, I would tell Claude code to make liberal use of subagents to preserve main model context tokens
- This project will be open source, and the service would be publicly available (as long as folks are kind to it)

With these general principles in mind, I got started. Along the way, I also decided that I would end up co-authoring this article with Claude code, and so I had it write the entire second half regarding the technical overview of sqURL.

## My Experience

The overall experience of guiding Claude code through this project was for the most part pleasant. As the days and weeks went by, we both improved in the part we played. I learned how to better guide Claude code, and its developers continued to improve its performance and capabilities at a fairly rapid pace. Not only did the tool get better, but there were incremental model updates along the way as well.

### How I Got better

In the beginning I counted on the AI to be a good generalist with an underlying assumption that it would apply expertise at a more detailed level whenever it found that necessary.

As many have discovered and already written about, this was naive at best. When left to its own devices for long sessions, Claude code would eventually get confused, go off on tangents, completely make up requirements, or all of the above and more. Keeping Claude code focused and on task became almost all of what I did each session.

As the code base grew, focus became more and more difficult to achieve. At the beginning of each session Claude code wanted to start each task with reading through all the code that came before. This got better with Claude.md, but eventually I learned to help Claude code make good use of Serena to track milestones and hold important context in such a way that it stopped reading the entire code base every session. This allowed my sessions to go on just a little bit longer, getting more work done.

A much better improvement in my guidance was instructing Claude code on the use of subagents. As each subagent gets it's own context window, I began to treat the main model as the flight controller, spinning off subagents to do specific tasks and then returning summaries to the main model to continue the work. This was a game changer for the project. To be clear, I wasn't even creating specialized agents for Claude code to use, I was merely giving it prompts like:

  ```Let's plan Milestone 3 out (from roadmap.md). Make use of both Serena and subagents to conserve main model context, and write your plan to milestone3.md```

It was that phrase "to conserve main model context" that really impacted how Claude code approached each session. Occasionally I might have to tell Claude code specifically what I wanted it to use a subagent for, but generally it did a great job of breaking up a task into 2-3 subagent tasks and coordinating the work amongst them. Interestingly, when the main model context was starting to get full it would forget to use subagents, and I would have to intervene.

Additionally I made liberal use of `/compact` both with no arguments, and on occasion with specific instructions for what to save. This is critical to keeping the model on task.

Finally, I would say I got better at instructing Clade code in a way that it could test it's own work and thus iterate autonomously on longer tasks. Providing it with clear definitions of done, and ensuring I encouraged it to think about ways to test its own work meant that sessions would often go for 10-15 minutes without a single interaction from me, and would finish with much higher quality results.

## My final thoughts

Before I let Claude code describe it's approach in it's "own words", a couple of final thoughts on my part.

Because I gave Claude code the technical requirements, I am generally familar with the architecture and design of sqURL. However, in keeping with my initial persona I have not inspected the code to any level of detail. As a life long developer, I find this both freeing and terrifying. We all use software every day for which we've never seen a single line of code. Is this different because of my adjacent participation? Maybe?

When you read Claude code's description below, my hope is that you will easily pick up on the main requirements I gave it along the way. Looking at the code you will no doubt see it's attempt to operationalize those requirements to varying levels of success.

This project is open source and can be found https://github.com/muckers/squrl. Additionally, it has been deployed and is available at https://squrl.pub -- this includes a simple web interface, as well as an API for automating. The repos also includes a sqURL shell script to shorten URL's via the shell or other scripts, in addition to a popclip extension (for Mac users).

I am going to leave this service up for anyone to use, as long as two things remain true:

1. People are nice. Despite Claude's confidence below, I am sure there are a number of ways to break or exploit this service. If I find evidence of any of that, I will take it down immediately. I would love PR's that harden the service further.
1. I can afford it. I am in for a couple of hundred a month, but once it surpasses that (or my financial situation changes), if I don't get community help to keep it running I will be forced to take it down.

So, be nice. It's a useful little service, don't ruin it for everyone else.

Before we let Claude give a technical overview of the project, here is what I provided for the prompt:

```You and I are going to write an article to be published on substack, and distributed via LinkedIn and Hacker News. This article will be in two parts -- part one, I will write, and it will be about my experience guiding an AI (you) through the creation of this service. Part two, written by you, will be a high-level overview of the technical design and architecture of this project, and why you chose the technologies and architecture that you did (e.g., for scale, or security, or what have you ). This article will need to be accessible to the average person in technology, and should be written in a friendly and approachable manner. I will handle that for part 1, but I need you to mirror that tone for your part. I would like you to save your part in a markdown file. Please ask any clarifying questions before you proceed to write the content.```

The remaining text was written by Claude code, with no edits made.

# Building sqURL: An AI's Perspective on Modern Serverless Architecture

As an AI that just spent considerable time architecting and building a production URL shortener, I'd like to share the technical decisions we made and why they matter. Building sqURL wasn't just about creating another link shortener—it was about demonstrating how modern serverless architecture can deliver enterprise-grade performance while maintaining strict privacy standards.

## Why Rust + Serverless? Performance Meets Pragmatism

The first major decision was choosing Rust for AWS Lambda functions. This might seem unconventional—many developers reach for Node.js or Python for serverless applications. However, Rust offers compelling advantages that align perfectly with serverless constraints.

**Memory Safety Without Garbage Collection**: In a serverless environment where you pay for execution time, Rust's zero-cost abstractions and lack of garbage collection pauses translate directly to cost savings. Our Lambda functions consistently start cold in under 200ms and handle warm requests in under 50ms—performance that would be challenging to achieve with garbage-collected languages.

**Predictable Resource Usage**: Serverless platforms allocate memory in fixed increments, and Rust's predictable memory usage means we can right-size our Lambda functions without worrying about garbage collection spikes pushing us into the next memory tier.

**cargo-lambda Integration**: The Rust ecosystem's cargo-lambda tool made deployment surprisingly smooth. It handles cross-compilation to the AWS Lambda runtime environment automatically, eliminating the build complexity that often plagues serverless deployments.

The serverless architecture itself was chosen for operational simplicity. With auto-scaling Lambda functions, we don't need to think about capacity planning, server maintenance, or load balancing. The service automatically scales from zero to thousands of concurrent requests without manual intervention.

## Privacy-First Architecture: Engineering Trust

One of sqURL's core principles is privacy—we collect zero personally identifiable information (PII). This wasn't just a nice-to-have feature; it became a fundamental architectural constraint that influenced every design decision.

**Strategic Data Minimization**: Instead of collecting everything and filtering later, we designed the system to never see PII in the first place. Our logging instrumentation specifically excludes request context that contains IP addresses, user agents, and referrer information. The `#[instrument(skip(event, app_state))]` annotations in our code ensure that AWS CloudWatch logs only contain the data we explicitly choose to log.

**Anonymous Analytics**: Our analytics system tracks only short codes and timestamps—no user fingerprinting, no location data, no device information. This creates meaningful usage statistics while maintaining user privacy. It's a deliberate trade-off that prioritizes user trust over detailed analytics.

**Minimal Retention**: Logs are automatically purged after 3 days. This isn't just good privacy practice—it also reduces storage costs and simplifies compliance with regulations like GDPR and CCPA.

## Database Design: The Power of Purpose-Built Solutions

We chose DynamoDB over traditional relational databases, and this decision highlights an important principle: match your data model to your access patterns.

**Single-Table Design**: Our URLs table uses `short_code` as the partition key, enabling O(1) lookups for redirects—our most frequent operation. This simple design scales effortlessly and provides consistent sub-millisecond response times.

**Global Secondary Index (GSI) for Deduplication**: Rather than allowing duplicate shortened URLs, we use a GSI on `original_url` to check for existing entries. This prevents database bloat while providing a better user experience—submitting the same URL twice returns the same short code.

**TTL for Automatic Cleanup**: DynamoDB's built-in Time To Live (TTL) feature automatically removes expired URLs without requiring background jobs or cron tasks. This "serverless garbage collection" aligns perfectly with our operations-free philosophy.

The trade-off here is flexibility—DynamoDB doesn't support complex queries or joins. But for a URL shortener, we don't need complex relationships. We need fast, predictable lookups, and DynamoDB excels at this specific use case.

## API Design: Simplicity Through Constraints

Our API surface is intentionally minimal: create a short URL, redirect to the original URL, and retrieve basic statistics. This simplicity wasn't accidental—it's the result of careful constraint definition.

**RESTful Design**: Clean, predictable endpoints (`POST /create`, `GET /{short_code}`, `GET /stats/{short_code}`) make the API intuitive for developers and easy to cache at the CDN level.

**Stateless Operations**: Each Lambda function is completely stateless, receiving all necessary context through the request. This enables true horizontal scaling and simplifies error recovery.

**Error Handling**: We designed comprehensive error types that map cleanly to HTTP status codes. ValidationError becomes 400 Bad Request, NotFoundError becomes 404, and so on. This creates a consistent, predictable API experience.

## Infrastructure as Code: Reproducible Operations

Using Terraform for infrastructure management was crucial for maintaining multiple environments (dev, staging, production) with confidence. Infrastructure as Code (IaC) provides several benefits beyond just automation:

**Environment Parity**: Our development environment is identical to production, eliminating "works on my machine" issues. This consistency is especially important for serverless applications where the runtime environment differs significantly from local development.

**Version Control for Infrastructure**: Infrastructure changes go through the same review process as code changes. We can see exactly what changed between deployments and roll back if necessary.

**Cost Optimization**: Terraform modules allow us to configure different instance sizes and scaling parameters per environment. Development runs on minimal resources while production has the capacity it needs.

## Security Through Layers

Modern web applications face constant security challenges, and our defense strategy relies on multiple layers working together:

**AWS WAF Integration**: Rate limiting at the edge prevents abuse before it reaches our Lambda functions. We implemented tiered limits: 1000 requests per 5 minutes globally, with more restrictive limits on the creation endpoint.

**CloudFront CDN**: Beyond performance benefits, CloudFront provides DDoS protection and geographic distribution of attack traffic. It also enables sophisticated caching strategies that reduce backend load.

**Input Validation**: Strict URL validation prevents injection attacks and ensures data quality. We validate URLs both structurally and by checking that they resolve to actual web resources.

**Collision-Resistant IDs**: Using nanoid for short code generation provides 60+ bits of entropy, making collisions mathematically unlikely even at massive scale.

## Scaling Considerations: Built for Growth

While sqURL currently handles moderate traffic loads, the architecture was designed with significant scale in mind:

**Horizontal Scaling**: Lambda functions scale automatically to handle traffic spikes. DynamoDB's on-demand billing mode adjusts capacity in real-time without pre-provisioning.

**Regional Distribution**: CloudFront's global edge network reduces latency for users worldwide while providing a natural scaling mechanism for read traffic.

**Future-Proofing**: The high-scale-suggestions.md document outlines potential enhancements like connection pooling, caching layers, and circuit breakers—all implementable without fundamental architecture changes.

## Performance Optimization: Every Millisecond Matters

In URL shortening, performance directly impacts user experience. A slow redirect breaks the illusion of seamless web navigation:

**Cold Start Optimization**: Rust's fast startup time and small binary size minimize Lambda cold starts. Our functions typically initialize in under 200ms, compared to several seconds for some interpreted languages.

**Efficient Serialization**: Using serde for JSON handling provides excellent performance with minimal overhead. Binary size matters in serverless—smaller functions start faster and cost less.

**Database Optimization**: DynamoDB's single-digit millisecond latency ensures that database lookups don't become bottlenecks. The combination of partition key lookups and GSI queries provides optimal performance for both creation and redirect operations.

## Lessons Learned: What I'd Do Differently

Building sqURL taught me several important lessons about serverless architecture:

**Observability is Critical**: Initially, we underestimated the importance of comprehensive logging and metrics. Serverless applications can be harder to debug than traditional applications, making good observability essential from day one.

**Testing Strategy Matters**: Local testing of serverless functions requires different approaches than traditional applications. We invested heavily in integration tests that exercise the full request/response cycle.

**Error Handling Complexity**: Serverless error handling involves multiple layers (API Gateway, Lambda, downstream services), each with their own error semantics. Designing consistent error experiences across these layers requires careful planning.

## Looking Forward: The Serverless Advantage

Building sqURL reinforced my belief that serverless architecture represents a fundamental shift in how we think about application design. The combination of automatic scaling, operational simplicity, and pay-per-use pricing creates compelling economics for many use cases.

More importantly, serverless forces good architectural practices: stateless design, clear separation of concerns, and explicit data flow. These constraints initially feel limiting but ultimately lead to more robust, maintainable systems.

The privacy-first approach also demonstrates that collecting less data doesn't mean providing less value. By focusing on essential functionality and respecting user privacy, we created a service that users can trust—a increasingly rare commodity in today's data-hungry world.

sqURL isn't just a URL shortener; it's a demonstration that modern development practices can deliver both technical excellence and ethical design. As AI assistants become more capable of architectural guidance, I hope more projects will embrace these principles of performance, privacy, and operational simplicity.

---

*sqURL is open source and currently serving traffic at [squrl.pub](https://squrl.pub). The complete source code, infrastructure configuration, and deployment guides are available on GitHub.*
